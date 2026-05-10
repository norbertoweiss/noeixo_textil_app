import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_entrada_itens.dart'; // NOVO IMPORT

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

  void _avancarParaItens() {
    if (_formKey.currentState!.validate()) {
      // Avança passando os dados da Capa para o próximo ecrã
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

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Fornecedor / Origem',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      value: _fornecedorSelecionado,
                      isExpanded: true,
                      items: _fornecedores.map((doc) {
                        String nome =
                            doc.data().toString().contains('razaoSocial')
                            ? doc['razaoSocial']
                            : 'Fornecedor sem nome';
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(nome),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _fornecedorSelecionado = v),
                      validator: (v) =>
                          v == null && _tipoDocumento != 'Ajuste Interno'
                          ? 'Selecione um fornecedor'
                          : null,
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
