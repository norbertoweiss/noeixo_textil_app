import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../insumos/form_insumo.dart';

class FormEntradaItens extends StatefulWidget {
  final String tipoDocumento;
  final String numeroDocumento;
  final String fornecedorId;

  const FormEntradaItens({
    super.key,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.fornecedorId,
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

  // Controladores e Focos para cálculo bidirecional
  final _qtdeController = TextEditingController();
  final _unitarioController = TextEditingController();
  final _totalController = TextEditingController();

  final FocusNode _qtdeFocus = FocusNode();
  final FocusNode _unitarioFocus = FocusNode();
  final FocusNode _totalFocus = FocusNode();

  List<DocumentSnapshot> _insumos = [];
  bool _carregando = true;
  bool _salvandoNota = false;

  @override
  void initState() {
    super.initState();
    _carregarInsumos();

    // Listeners inteligentes
    _qtdeController.addListener(_onQtdeChanged);
    _unitarioController.addListener(_onUnitarioChanged);
    _totalController.addListener(_onTotalChanged);
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

  Future<void> _carregarInsumos() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('insumos')
        .where('clienteId', isEqualTo: 'teste_textil')
        .where('ativo', isEqualTo: true)
        .get();

    if (mounted) {
      setState(() {
        _insumos = snapshot.docs;
        _insumos.sort(
          (a, b) => a['nome'].toString().toLowerCase().compareTo(
            b['nome'].toString().toLowerCase(),
          ),
        );
        _carregando = false;
      });
    }
  }

  // --- LÓGICA DE CÁLCULO BIDIRECIONAL ---
  double _parse(String valor) {
    return double.tryParse(valor.replaceAll('.', '').replaceAll(',', '.')) ??
        0.0;
  }

  void _onQtdeChanged() {
    if (_qtdeFocus.hasFocus) {
      double q = _parse(_qtdeController.text);
      double u = _parse(_unitarioController.text);
      if (q > 0 && u > 0) {
        _totalController.text = (q * u).toStringAsFixed(2).replaceAll('.', ',');
      }
    }
  }

  void _onUnitarioChanged() {
    if (_unitarioFocus.hasFocus) {
      double q = _parse(_qtdeController.text);
      double u = _parse(_unitarioController.text);
      if (q > 0 && u > 0) {
        _totalController.text = (q * u).toStringAsFixed(2).replaceAll('.', ',');
      }
    }
  }

  void _onTotalChanged() {
    if (_totalFocus.hasFocus) {
      double q = _parse(_qtdeController.text);
      double t = _parse(_totalController.text);
      if (q > 0 && t > 0) {
        _unitarioController.text = (t / q)
            .toStringAsFixed(4)
            .replaceAll('.', ',');
      }
    }
  }
  // --------------------------------------

  void _adicionarItemRascunho() {
    if (_formKeyItem.currentState!.validate()) {
      double qtde = _parse(_qtdeController.text);
      double unit = _parse(_unitarioController.text);
      double total = _parse(_totalController.text);

      if (qtde <= 0 || total <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quantidade e Total devem ser maiores que zero.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _itensTemporarios.add({
          'tipo': _tipoLinha,
          'insumoId': _insumoSelecionado,
          'nomeInsumo': _nomeInsumoSelecionado,
          'quantidade': qtde,
          'valorUnitario': unit,
          'valorTotal': total,
        });

        // Limpar os campos
        _insumoSelecionado = null;
        _nomeInsumoSelecionado = '';
        _qtdeController.clear();
        _unitarioController.clear();
        _totalController.clear();
      });
    }
  }

  void _removerItem(int index) {
    setState(() {
      _itensTemporarios.removeAt(index);
    });
  }

  Future<void> _salvarNotaFinal(String status) async {
    if (_itensTemporarios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos um item antes de salvar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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

      await FirebaseFirestore.instance
          .collection('entradas_estoque')
          .add(dadosNota);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nota $status com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar nota: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvandoNota = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2. Itens da Entrada'),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<String>(
                              value: 'Insumo',
                              groupValue: _tipoLinha,
                              onChanged: (v) => setState(() => _tipoLinha = v!),
                            ),
                            const Text('Produto/Insumo'),
                            Radio<String>(
                              value: 'Serviço',
                              groupValue: _tipoLinha,
                              onChanged: (v) => setState(() => _tipoLinha = v!),
                            ),
                            const Text('Serviço/Despesa'),
                          ],
                        ),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: _tipoLinha == 'Insumo'
                                      ? 'Selecione o Insumo'
                                      : 'Selecione o Serviço',
                                  border: const OutlineInputBorder(),
                                ),
                                value: _insumoSelecionado,
                                isExpanded: true,
                                items: _insumos.map((doc) {
                                  return DropdownMenuItem(
                                    value: doc.id,
                                    child: Text(doc['nome']),
                                  );
                                }).toList(),
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
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.teal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const FormInsumo(),
                                    ),
                                  );
                                  _carregarInsumos();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // NOVA DISPOSIÇÃO: 3 Campos conversando entre si
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _qtdeController,
                                focusNode: _qtdeFocus,
                                decoration: const InputDecoration(
                                  labelText: 'Qtde Total',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Obrigatório' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _unitarioController,
                                focusNode: _unitarioFocus,
                                decoration: const InputDecoration(
                                  labelText: 'Custo Unit. (R\$)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Obrigatório' : null,
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
                                  labelText: 'Valor Total (R\$)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Obrigatório' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _adicionarItemRascunho,
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                size: 16,
                              ),
                              label: const Text('Inserir Item'),
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
                            'Nenhum item adicionado à nota ainda.',
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
                                leading: CircleAvatar(
                                  backgroundColor: item['tipo'] == 'Insumo'
                                      ? Colors.blueGrey
                                      : Colors.orange,
                                  child: Icon(
                                    item['tipo'] == 'Insumo'
                                        ? Icons.inventory_2
                                        : Icons.build,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  item['nomeInsumo'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Qtde: ${item['quantidade']} un | Unit: R\$ ${item['valorUnitario'].toStringAsFixed(4)}\nTotal: R\$ ${item['valorTotal'].toStringAsFixed(2)}',
                                ),
                                isThreeLine: true,
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: _salvandoNota
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _salvarNotaFinal('Em Digitação'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  foregroundColor: Colors.teal,
                                ),
                                child: const Text('GUARDAR RASCUNHO'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _salvarNotaFinal('Efetivada'),
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
