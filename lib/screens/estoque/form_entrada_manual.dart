import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_entrada_itens.dart';
import '../fornecedores/form_fornecedor.dart'; // NOVO IMPORT: Para chamar o cadastro de fornecedor

class FormEntradaManual extends StatefulWidget {
  const FormEntradaManual({super.key});

  @override
  State<FormEntradaManual> createState() => _FormEntradaManualState();
}

class _FormEntradaManualState extends State<FormEntradaManual> {
  final _formKey = GlobalKey<FormState>();

  String _tipoDocumento = 'NF-e (Nota Quente)';
  final _numeroDocController = TextEditingController();
  String? _fornecedorSelecionado;

  List<DocumentSnapshot> _fornecedores = [];
  bool _carregandoFornecedores = true;

  @override
  void initState() {
    super.initState();
    _carregarFornecedores();
  }

  Future<void> _carregarFornecedores() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('fornecedores')
          .where('clienteId', isEqualTo: 'teste_textil')
          .get();

      if (mounted) {
        setState(() {
          _fornecedores = snapshot.docs;
          _carregandoFornecedores = false;
        });
      }
    } catch (e) {
      setState(() => _carregandoFornecedores = false);
    }
  }

  String _obterNomeFornecedor(Map<String, dynamic> data) {
    if (data.containsKey('nomeFantasia') &&
        data['nomeFantasia'].toString().trim().isNotEmpty)
      return data['nomeFantasia'];
    if (data.containsKey('razaoSocial') &&
        data['razaoSocial'].toString().trim().isNotEmpty)
      return data['razaoSocial'];
    if (data.containsKey('nome') && data['nome'].toString().trim().isNotEmpty)
      return data['nome'];
    return 'Fornecedor sem nome';
  }

  void _avancarParaItens() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FormEntradaItens(
            tipoDocumento: _tipoDocumento,
            numeroDocumento: _numeroDocController.text.trim(),
            fornecedorId: _fornecedorSelecionado ?? '',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Entrada - Capa'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _carregandoFornecedores
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Dados do Documento (Capa)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Entrada',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt),
                      ),
                      value: _tipoDocumento,
                      items: const [
                        DropdownMenuItem(
                          value: 'NF-e (Nota Quente)',
                          child: Text('NF-e (Nota Fiscal Oficial)'),
                        ),
                        DropdownMenuItem(
                          value: 'Recibo (Nota Fria)',
                          child: Text('Recibo / Nota Simples (Fria)'),
                        ),
                        DropdownMenuItem(
                          value: 'Ajuste Interno',
                          child: Text('Ajuste de Saldo / Retorno'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _tipoDocumento = v!),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _numeroDocController,
                      decoration: const InputDecoration(
                        labelText: 'Nº do Documento (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // A MÁGICA ACONTECE AQUI: O Autocomplete e o botão "+" lado a lado
                    Row(
                      children: [
                        Expanded(
                          child: Autocomplete<DocumentSnapshot>(
                            displayStringForOption: (doc) =>
                                _obterNomeFornecedor(
                                  doc.data() as Map<String, dynamic>,
                                ),
                            optionsBuilder: (TextEditingValue textValue) {
                              if (textValue.text.isEmpty) {
                                return _fornecedores;
                              }
                              return _fornecedores.where((doc) {
                                final nome = _obterNomeFornecedor(
                                  doc.data() as Map<String, dynamic>,
                                ).toLowerCase();
                                return nome.contains(
                                  textValue.text.toLowerCase(),
                                );
                              });
                            },
                            onSelected: (DocumentSnapshot selection) {
                              setState(() {
                                _fornecedorSelecionado = selection.id;
                              });
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Fornecedor / Origem (Digite para buscar)',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.search),
                                      hintText: 'Comece a escrever o nome...',
                                    ),
                                    validator: (v) {
                                      if (_tipoDocumento == 'Ajuste Interno')
                                        return null;
                                      if (_fornecedorSelecionado == null)
                                        return 'Selecione um fornecedor da lista';
                                      return null;
                                    },
                                    onChanged: (v) {
                                      if (v.isEmpty)
                                        setState(
                                          () => _fornecedorSelecionado = null,
                                        );
                                    },
                                  );
                                },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            tooltip: 'Cadastrar Novo Fornecedor',
                            onPressed: () async {
                              // 1. Vai para a tela de Fornecedor
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FormFornecedor(),
                                ),
                              );
                              // 2. Quando voltar, recarrega a lista do Firebase!
                              _carregarFornecedores();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _avancarParaItens,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text(
                          'AVANÇAR PARA ITENS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
