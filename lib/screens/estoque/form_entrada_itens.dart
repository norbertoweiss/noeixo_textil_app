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

  final FocusNode _qtdeFocus = FocusNode();
  final FocusNode _unitarioFocus = FocusNode();
  final FocusNode _totalFocus = FocusNode();

  List<DocumentSnapshot> _insumos = [];
  List<DocumentSnapshot> _formasPagamento = [];
  List<DocumentSnapshot> _condicoesPagamento = [];

  bool _carregando = true;
  bool _salvandoNota = false;

  @override
  void initState() {
    super.initState();
    _inicializarDados();

    _qtdeController.addListener(_onQtdeChanged);
    _unitarioController.addListener(_onUnitarioChanged);
    _totalController.addListener(_onTotalChanged);
  }

  Future<void> _inicializarDados() async {
    var snapshotInsumos = await FirebaseFirestore.instance
        .collection('insumos')
        .where('clienteId', isEqualTo: 'teste_textil')
        .where('ativo', isEqualTo: true)
        .get();
    var snapshotFormas = await FirebaseFirestore.instance
        .collection('formas_pagamento')
        .where('clienteId', isEqualTo: 'teste_textil')
        .where('ativo', isEqualTo: true)
        .get();
    var snapshotCondicoes = await FirebaseFirestore.instance
        .collection('condicoes_pagamento')
        .where('clienteId', isEqualTo: 'teste_textil')
        .where('ativo', isEqualTo: true)
        .get();

    if (widget.documentoId != null) {
      var docNota = await FirebaseFirestore.instance
          .collection('entradas_estoque')
          .doc(widget.documentoId)
          .get();
      if (docNota.exists) {
        final dados = docNota.data() as Map<String, dynamic>;
        _itensTemporarios = List<Map<String, dynamic>>.from(
          dados['itens'] ?? [],
        );
      }
    }

    if (mounted) {
      setState(() {
        _insumos = snapshotInsumos.docs;
        _formasPagamento = snapshotFormas.docs;
        _condicoesPagamento = snapshotCondicoes.docs;

        _insumos.sort(
          (a, b) => a['nome'].toString().toLowerCase().compareTo(
            b['nome'].toString().toLowerCase(),
          ),
        );
        _carregando = false;
      });
    }
  }

  @override
  void dispose() {
    _qtdeController.dispose();
    _unitarioController.dispose();
    _totalController.dispose();
    _qtdeFocus.dispose();
    _unitarioFocus.dispose();
    _totalFocus.dispose();
    super.dispose();
  }

  double _parse(String valor) {
    return double.tryParse(valor.replaceAll('.', '').replaceAll(',', '.')) ??
        0.0;
  }

  void _onQtdeChanged() {
    if (_qtdeFocus.hasFocus) {
      double q = _parse(_qtdeController.text);
      double u = _parse(_unitarioController.text);
      if (q > 0 && u > 0)
        _totalController.text = (q * u).toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  void _onUnitarioChanged() {
    if (_unitarioFocus.hasFocus) {
      double q = _parse(_qtdeController.text);
      double u = _parse(_unitarioController.text);
      if (q > 0 && u > 0)
        _totalController.text = (q * u).toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  void _onTotalChanged() {
    if (_totalFocus.hasFocus) {
      double q = _parse(_qtdeController.text);
      double t = _parse(_totalController.text);
      if (q > 0 && t > 0)
        _unitarioController.text = (t / q)
            .toStringAsFixed(4)
            .replaceAll('.', ',');
    }
  }

  void _adicionarItemRascunho() {
    if (_formKeyItem.currentState!.validate()) {
      double qtde = _parse(_qtdeController.text);
      double unit = _parse(_unitarioController.text);
      double total = _parse(_totalController.text);

      setState(() {
        _itensTemporarios.add({
          'tipo': _tipoLinha,
          'insumoId': _insumoSelecionado,
          'nomeInsumo': _nomeInsumoSelecionado,
          'quantidade': qtde,
          'valorUnitario': unit,
          'valorTotal': total,
        });
        _insumoSelecionado = null;
        _nomeInsumoSelecionado = '';
        _qtdeController.clear();
        _unitarioController.clear();
        _totalController.clear();
      });
    }
  }

  void _removerItem(int index) {
    setState(() => _itensTemporarios.removeAt(index));
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  // ==========================================
  // O CÉREBRO: PAINEL FINANCEIRO DE PARCELAMENTO
  // ==========================================
  void _abrirPainelFinanceiro() {
    if (_itensTemporarios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos um item.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double totalNota = _itensTemporarios.fold(
      0,
      (sum, item) => sum + item['valorTotal'],
    );
    if (totalNota <= 0) {
      _salvarNotaFinal('Efetivada');
      return;
    }

    String? formaSelecionada;
    DocumentSnapshot? condicaoSelecionada;
    int qtdeParcelas = 1;
    DateTime dataPrimeiroVencimento = DateTime.now();
    List<Map<String, dynamic>> parcelasGeradas = [];
    final qtdeController = TextEditingController(text: '1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void gerarParcelas() {
              if (condicaoSelecionada == null || formaSelecionada == null)
                return;
              parcelasGeradas.clear();
              double valorParcela = totalNota / qtdeParcelas;

              String unidade = condicaoSelecionada!['unidadeTempo'];
              int intervalo = condicaoSelecionada!['intervalo'];

              for (int i = 0; i < qtdeParcelas; i++) {
                DateTime dataCalculada = dataPrimeiroVencimento;

                // Motor de Recorrência Inteligente (Dias, Meses ou Anos)
                if (unidade == 'Dias') {
                  dataCalculada = dataPrimeiroVencimento.add(
                    Duration(days: intervalo * i),
                  );
                } else if (unidade == 'Meses') {
                  dataCalculada = DateTime(
                    dataPrimeiroVencimento.year,
                    dataPrimeiroVencimento.month + (intervalo * i),
                    dataPrimeiroVencimento.day,
                  );
                } else if (unidade == 'Anos') {
                  dataCalculada = DateTime(
                    dataPrimeiroVencimento.year + (intervalo * i),
                    dataPrimeiroVencimento.month,
                    dataPrimeiroVencimento.day,
                  );
                }

                parcelasGeradas.add({
                  'vencimento': dataCalculada,
                  'valor': valorParcela,
                  'formaPagamentoId': formaSelecionada,
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lançamento Financeiro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Valor Total da Nota: R\$ ${totalNota.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Divider(),

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Forma de Pagamento',
                        border: OutlineInputBorder(),
                      ),
                      value: formaSelecionada,
                      items: _formasPagamento
                          .map(
                            (doc) => DropdownMenuItem(
                              value: doc.id,
                              child: Text(doc['nome']),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() {
                        formaSelecionada = v;
                        gerarParcelas();
                      }),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<DocumentSnapshot>(
                      decoration: const InputDecoration(
                        labelText: 'Prazo / Condição',
                        border: OutlineInputBorder(),
                      ),
                      value: condicaoSelecionada,
                      items: _condicoesPagamento
                          .map(
                            (doc) => DropdownMenuItem(
                              value: doc,
                              child: Text(doc['nome']),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() {
                        condicaoSelecionada = v;
                        gerarParcelas();
                      }),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: qtdeController,
                            decoration: const InputDecoration(
                              labelText: 'Qtde Parcelas',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              int? num = int.tryParse(v);
                              if (num != null && num > 0) {
                                setModalState(() {
                                  qtdeParcelas = num;
                                  gerarParcelas();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: dataPrimeiroVencimento,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  dataPrimeiroVencimento = picked;
                                  gerarParcelas();
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '1º Vencimento',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _formatarData(dataPrimeiroVencimento),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    if (parcelasGeradas.isNotEmpty) ...[
                      const Text(
                        'Previsão de Pagamentos (Clique na data para editar):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: parcelasGeradas.length,
                          itemBuilder: (context, index) {
                            final p = parcelasGeradas[index];
                            return Card(
                              color: Colors.teal.shade50,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: InkWell(
                                  onTap: () async {
                                    // PERMITE EDITAR MANUALMENTE UMA DATA ESPECÍFICA (Ex: Caiu no domingo)
                                    DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: p['vencimento'],
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2101),
                                    );
                                    if (picked != null)
                                      setModalState(
                                        () =>
                                            parcelasGeradas[index]['vencimento'] =
                                                picked,
                                      );
                                  },
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.edit_calendar,
                                        size: 16,
                                        color: Colors.teal,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatarData(p['vencimento']),
                                        style: const TextStyle(
                                          decoration: TextDecoration.underline,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Text(
                                  'R\$ ${p['valor'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: const Text(
                          'CONFIRMAR NOTA E FINANCEIRO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          if (formaSelecionada == null ||
                              condicaoSelecionada == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Selecione Forma e Prazo!'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context); // Fecha painel financeiro
                          _salvarNotaFinal(
                            'Efetivada',
                            parcelasGeradas,
                          ); // Dispara a gravação em lote
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // O GRAVADOR (BATCH) - ESTOQUE + FINANCEIRO
  // ==========================================
  Future<void> _salvarNotaFinal(
    String status, [
    List<Map<String, dynamic>>? parcelasFinanceiras,
  ]) async {
    setState(() => _salvandoNota = true);

    try {
      double valorTotalNota = _itensTemporarios.fold(
        0,
        (sum, item) => sum + item['valorTotal'],
      );

      final dadosNota = {
        'clienteId': 'teste_textil',
        'tipoDocumento': widget.tipoDocumento,
        'numeroDocumento': widget.numeroDocumento,
        'fornecedorId': widget.fornecedorId,
        'status': status,
        'dataRegistro': FieldValue.serverTimestamp(),
        'valorTotal': valorTotalNota,
        'itens': _itensTemporarios,
      };

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Grava a Capa da Nota
      DocumentReference docNota = widget.documentoId == null
          ? FirebaseFirestore.instance.collection('entradas_estoque').doc()
          : FirebaseFirestore.instance
                .collection('entradas_estoque')
                .doc(widget.documentoId);

      batch.set(docNota, dadosNota);

      if (status == 'Efetivada') {
        // 2. Atualiza o Estoque
        for (var item in _itensTemporarios) {
          if (item['tipo'] == 'Insumo' && item['insumoId'] != null) {
            DocumentReference docInsumo = FirebaseFirestore.instance
                .collection('insumos')
                .doc(item['insumoId']);
            batch.update(docInsumo, {
              'estoqueAtual': FieldValue.increment(item['quantidade']),
              'custoBase': item['valorUnitario'], // Atualiza Ficha Técnica
            });
          }
        }

        // 3. Injeta no Contas a Pagar
        if (parcelasFinanceiras != null) {
          for (int i = 0; i < parcelasFinanceiras.length; i++) {
            var parcela = parcelasFinanceiras[i];
            DocumentReference docConta = FirebaseFirestore.instance
                .collection('contas_a_pagar')
                .doc();
            batch.set(docConta, {
              'clienteId': 'teste_textil',
              'fornecedorId': widget.fornecedorId,
              'entradaEstoqueId': docNota.id,
              'numeroDocumento': widget.numeroDocumento,
              'parcela': '${i + 1}/${parcelasFinanceiras.length}',
              'dataEmissao': FieldValue.serverTimestamp(),
              'dataVencimento': Timestamp.fromDate(parcela['vencimento']),
              'valor': parcela['valor'],
              'formaPagamentoId': parcela['formaPagamentoId'],
              'status': 'Pendente',
            });
          }
        }
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        if (widget.documentoId == null) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nota salva como $status!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.documentoId == null ? '2. Itens da Entrada' : 'Editar Itens',
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Form(
                    key: _formKeyItem,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Radio<String>(
                              value: 'Insumo',
                              groupValue: _tipoLinha,
                              onChanged: (v) => setState(() => _tipoLinha = v!),
                            ),
                            const Text('Insumo'),
                            Radio<String>(
                              value: 'Serviço',
                              groupValue: _tipoLinha,
                              onChanged: (v) => setState(() => _tipoLinha = v!),
                            ),
                            const Text('Serviço'),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Selecione o Item',
                                  border: OutlineInputBorder(),
                                ),
                                value: _insumoSelecionado,
                                isExpanded: true,
                                items: _insumos
                                    .map(
                                      (doc) => DropdownMenuItem(
                                        value: doc.id,
                                        child: Text(doc['nome']),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _insumoSelecionado = v;
                                    _nomeInsumoSelecionado = _insumos
                                        .firstWhere(
                                          (doc) => doc.id == v,
                                        )['nome'];
                                  });
                                },
                                validator: (v) =>
                                    v == null ? 'Obrigatório' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const FormInsumo(),
                                  ),
                                );
                                _inicializarDados();
                              },
                              icon: const Icon(Icons.add),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.teal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _qtdeController,
                                focusNode: _qtdeFocus,
                                decoration: const InputDecoration(
                                  labelText: 'Qtde',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _unitarioController,
                                focusNode: _unitarioFocus,
                                decoration: const InputDecoration(
                                  labelText: 'Unitário (R\$)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _totalController,
                                focusNode: _totalFocus,
                                decoration: const InputDecoration(
                                  labelText: 'Total (R\$)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _adicionarItemRascunho,
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                size: 16,
                              ),
                              label: const Text('Inserir'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade50,
                                foregroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 2),
                Expanded(
                  child: _itensTemporarios.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum item na nota.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _itensTemporarios.length,
                          itemBuilder: (context, index) {
                            final item = _itensTemporarios[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  item['tipo'] == 'Insumo'
                                      ? Icons.inventory_2
                                      : Icons.build,
                                  color: Colors.teal,
                                ),
                                title: Text(
                                  item['nomeInsumo'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Qtde: ${item['quantidade']} | Total: R\$ ${item['valorTotal'].toStringAsFixed(2)}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removerItem(index),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: _salvandoNota
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _salvarNotaFinal('Em Digitação'),
                                child: const Text('GUARDAR RASCUNHO'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    _abrirPainelFinanceiro, // <--- AQUI A MÁGICA ACONTECE
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('EFETIVAR NOTA'),
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
