import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../insumos/form_insumo.dart';

class FormEntradaItens extends StatefulWidget {
  final String tipoDocumento;
  final String numeroDocumento;
  final String fornecedorId;
  final String? documentoId;

  const FormEntradaItens({
    super.key,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.fornecedorId,
    this.documentoId,
  });

  @override
  State<FormEntradaItens> createState() => _FormEntradaItensState();
}

class _FormEntradaItensState extends State<FormEntradaItens> {
  final _formKeyItem = GlobalKey<FormState>();

  List<Map<String, dynamic>> _itensTemporarios = [];

  String _tipoLinha = 'Insumo';
  String? _insumoSelecionado;
  String _nomeInsumoSelecionado = '';

  final _qtdeController = TextEditingController();
  final _unitarioController = TextEditingController();
  final _totalController = TextEditingController();
  final _pesquisaController = TextEditingController();

  final FocusNode _qtdeFocus = FocusNode();
  final FocusNode _unitarioFocus = FocusNode();
  final FocusNode _totalFocus = FocusNode();

  List<Map<String, dynamic>> _insumosCadastrados = [];
  bool _carregandoInsumos = true;
  bool _salvandoNota = false;

  @override
  void initState() {
    super.initState();
    _carregarInsumos();
    if (widget.documentoId != null) {
      _carregarRascunho();
    }
  }

  @override
  void dispose() {
    _qtdeController.dispose();
    _unitarioController.dispose();
    _totalController.dispose();
    _pesquisaController.dispose();
    _qtdeFocus.dispose();
    _unitarioFocus.dispose();
    _totalFocus.dispose();
    super.dispose();
  }

  // =========================================================================
  // MOTOR DE BUSCA E INTEGRAÇÃO COM O CATÁLOGO
  // =========================================================================
  Future<void> _carregarInsumos() async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('insumos')
          .where('clienteId', isEqualTo: 'teste_textil')
          .where('ativo', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> lista = [];
      for (var doc in snap.docs) {
        var dados = doc.data();
        dados['id'] = doc.id;
        lista.add(dados);
      }

      if (mounted) {
        setState(() {
          _insumosCadastrados = lista;
          _carregandoInsumos = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _carregandoInsumos = false);
    }
  }

  Future<void> _carregarRascunho() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('entradas_estoque')
          .doc(widget.documentoId)
          .get();
      if (doc.exists) {
        var dados = doc.data() as Map<String, dynamic>;
        if (dados['itens'] != null) {
          setState(() {
            _itensTemporarios = List<Map<String, dynamic>>.from(dados['itens']);
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar rascunho: $e');
    }
  }

  // =========================================================================
  // MATEMÁTICA DA NOTA
  // =========================================================================
  void _calcularValores(String origem) {
    double qtde =
        double.tryParse(_qtdeController.text.replaceAll(',', '.')) ?? 0;
    double unitario =
        double.tryParse(_unitarioController.text.replaceAll(',', '.')) ?? 0;
    double total =
        double.tryParse(_totalController.text.replaceAll(',', '.')) ?? 0;

    if (origem == 'unitario' && qtde > 0) {
      _totalController.text = (qtde * unitario).toStringAsFixed(2);
    } else if (origem == 'total' && qtde > 0) {
      _unitarioController.text = (total / qtde).toStringAsFixed(4);
    }
  }

  void _adicionarItemNaLista() {
    if (!_formKeyItem.currentState!.validate()) return;
    if (_tipoLinha == 'Insumo' && _insumoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um Insumo!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _itensTemporarios.add({
        'tipo': _tipoLinha,
        'insumoId': _insumoSelecionado,
        'nomeInsumo': _tipoLinha == 'Insumo'
            ? _nomeInsumoSelecionado
            : 'Serviço/Frete',
        'quantidade':
            double.tryParse(_qtdeController.text.replaceAll(',', '.')) ?? 0,
        'valorUnitario':
            double.tryParse(_unitarioController.text.replaceAll(',', '.')) ?? 0,
        'valorTotal':
            double.tryParse(_totalController.text.replaceAll(',', '.')) ?? 0,
      });

      // Limpa os campos para o próximo item
      _insumoSelecionado = null;
      _nomeInsumoSelecionado = '';
      _pesquisaController.clear();
      _qtdeController.clear();
      _unitarioController.clear();
      _totalController.clear();
      _qtdeFocus.requestFocus();
    });
  }

  void _removerItem(int index) {
    setState(() {
      _itensTemporarios.removeAt(index);
    });
  }

  double get _somaTotalNota {
    return _itensTemporarios.fold(
      0.0,
      (soma, item) => soma + (item['valorTotal'] ?? 0.0),
    );
  }

  // =========================================================================
  // GRAVAÇÃO E EFETIVAÇÃO
  // =========================================================================
  Future<void> _salvarNotaFinal(String statusFinal) async {
    if (_itensTemporarios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos um item à nota.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _salvandoNota = true);

    try {
      final db = FirebaseFirestore.instance;
      WriteBatch batch = db.batch();

      DocumentReference refNota;
      if (widget.documentoId != null) {
        refNota = db.collection('entradas_estoque').doc(widget.documentoId);
      } else {
        refNota = db.collection('entradas_estoque').doc();
      }

      batch.set(refNota, {
        'clienteId': 'teste_textil',
        'tipoDocumento': widget.tipoDocumento,
        'numeroDocumento': widget.numeroDocumento,
        'fornecedorId': widget.fornecedorId,
        'valorTotal': _somaTotalNota,
        'itens': _itensTemporarios,
        'status': statusFinal,
        'dataRegistro': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Se for EFETIVAR, dá entrada física no estoque
      if (statusFinal == 'EFETIVADA') {
        for (var item in _itensTemporarios) {
          if (item['tipo'] == 'Insumo' && item['insumoId'] != null) {
            DocumentReference refInsumo = db
                .collection('insumos')
                .doc(item['insumoId']);
            batch.update(refInsumo, {
              'estoqueAtual': FieldValue.increment(item['quantidade']),
              'custoBase':
                  item['valorUnitario'], // Atualiza o custo médio/base do insumo
              'dataAtualizacao': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Volta para a tela principal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              statusFinal == 'EFETIVADA'
                  ? 'Nota Efetivada! Estoque Atualizado.'
                  : 'Rascunho Guardado!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _salvandoNota = false);
    }
  }

  void _abrirPainelFinanceiro() {
    // Este seria o popup para gerar as parcelas de contas a pagar antes de efetivar.
    // Para simplificar o fluxo agora, efetivamos diretamente.
    _salvarNotaFinal('EFETIVADA');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Itens: ${widget.numeroDocumento}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _carregandoInsumos
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ================= PAINEL DE DIGITAÇÃO =================
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKeyItem,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Tipo',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                value: _tipoLinha,
                                items: ['Insumo', 'Serviço', 'Frete']
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _tipoLinha = v!),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // O MOTOR PREDITIVO COM O "+" (A Mágica)
                            Expanded(
                              flex: 5,
                              child: _tipoLinha != 'Insumo'
                                  ? const SizedBox.shrink()
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: Autocomplete<Map<String, dynamic>>(
                                            optionsBuilder:
                                                (
                                                  TextEditingValue
                                                  textEditingValue,
                                                ) {
                                                  if (textEditingValue
                                                      .text
                                                      .isEmpty)
                                                    return const Iterable<
                                                      Map<String, dynamic>
                                                    >.empty();
                                                  return _insumosCadastrados.where(
                                                    (
                                                      insumo,
                                                    ) => (insumo['nome'] ?? '')
                                                        .toString()
                                                        .toLowerCase()
                                                        .contains(
                                                          textEditingValue.text
                                                              .toLowerCase(),
                                                        ),
                                                  );
                                                },
                                            displayStringForOption: (option) =>
                                                option['nome'] ?? '',
                                            onSelected: (selection) {
                                              setState(() {
                                                _insumoSelecionado =
                                                    selection['id'];
                                                _nomeInsumoSelecionado =
                                                    selection['nome'];
                                              });
                                              _qtdeFocus
                                                  .requestFocus(); // Pula para a quantidade
                                            },
                                            fieldViewBuilder:
                                                (
                                                  context,
                                                  controller,
                                                  focusNode,
                                                  onFieldSubmitted,
                                                ) {
                                                  if (controller.text !=
                                                      _pesquisaController.text)
                                                    controller.text =
                                                        _pesquisaController
                                                            .text;
                                                  controller.addListener(() {
                                                    _pesquisaController.text =
                                                        controller.text;
                                                  });

                                                  return TextFormField(
                                                    controller: controller,
                                                    focusNode: focusNode,
                                                    decoration: const InputDecoration(
                                                      labelText:
                                                          'Pesquisar Insumo...',
                                                      border:
                                                          OutlineInputBorder(),
                                                      isDense: true,
                                                      prefixIcon: Icon(
                                                        Icons.search,
                                                      ),
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // O BOTÃO DE CADASTRO ON-THE-FLY
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.teal,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              color: Colors.white,
                                            ),
                                            tooltip: 'Cadastrar Novo Insumo',
                                            onPressed: () async {
                                              // Abre o "Camaleão" sem sair da nota!
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const FormInsumo(),
                                                ),
                                              );
                                              _carregarInsumos(); // Recarrega a lista para achar o que acabou de criar
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qtdeController,
                                focusNode: _qtdeFocus,
                                decoration: const InputDecoration(
                                  labelText: 'Qtde',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _calcularValores('unitario'),
                                validator: (v) => v!.isEmpty ? '*' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _unitarioController,
                                focusNode: _unitarioFocus,
                                decoration: const InputDecoration(
                                  labelText: 'V. Unit',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _calcularValores('unitario'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _totalController,
                                focusNode: _totalFocus,
                                decoration: const InputDecoration(
                                  labelText: 'Total Item',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.black12,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => _calcularValores('total'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(
                                Icons.keyboard_return,
                                color: Colors.white,
                              ),
                              onPressed: _adicionarItemNaLista,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ================= LISTA DE ITENS LANÇADOS =================
                Container(
                  width: double.infinity,
                  color: Colors.teal.shade800,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_itensTemporarios.length} Itens Lançados',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'TOTAL: R\$ ${_somaTotalNota.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _itensTemporarios.length,
                    itemBuilder: (context, index) {
                      final item = _itensTemporarios[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade50,
                            child: Text(
                              (index + 1).toString(),
                              style: TextStyle(
                                color: Colors.teal.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            item['nomeInsumo'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Qtde: ${item['quantidade']} x R\$ ${item['valorUnitario']} = R\$ ${item['valorTotal']}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removerItem(index),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ================= RODAPÉ DE AÇÕES =================
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: _salvandoNota
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.teal),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: () =>
                                    _salvarNotaFinal('Em Digitação'),
                                child: const Text(
                                  'GUARDAR RASCUNHO',
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _abrirPainelFinanceiro,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text(
                                  'EFETIVAR NOTA',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
