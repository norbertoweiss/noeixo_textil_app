import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormFornecedor extends StatefulWidget {
  final DocumentSnapshot? fornecedorParaEditar;
  const FormFornecedor({super.key, this.fornecedorParaEditar});

  @override
  State<FormFornecedor> createState() => _FormFornecedorState();
}

class _FormFornecedorState extends State<FormFornecedor> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _documentoController = TextEditingController();
  final _contatoController = TextEditingController();

  String? _categoriaSelecionada;
  String? _subcategoriaSelecionada;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    if (widget.fornecedorParaEditar != null) {
      final data = widget.fornecedorParaEditar!.data() as Map<String, dynamic>;
      _nomeController.text = data['nome'] ?? '';
      _documentoController.text = data['documento'] ?? '';
      _contatoController.text = data['contato'] ?? '';
      _categoriaSelecionada = data['grupoNome'];
      _subcategoriaSelecionada = data['subcategoria'];
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _documentoController.dispose();
    _contatoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    final dados = {
      'clienteId': 'teste_textil',
      'nome': _nomeController.text.trim(),
      'documento': _documentoController.text.trim(),
      'contato': _contatoController.text.trim(),
      'grupoNome': _categoriaSelecionada ?? 'Geral',
      'subcategoria': _subcategoriaSelecionada ?? 'Geral',
      'ativo': widget.fornecedorParaEditar != null
          ? (widget.fornecedorParaEditar!.data()
                    as Map<String, dynamic>)['ativo'] ??
                true
          : true,
    };

    try {
      if (widget.fornecedorParaEditar == null) {
        await FirebaseFirestore.instance.collection('fornecedores').add(dados);
      } else {
        await FirebaseFirestore.instance
            .collection('fornecedores')
            .doc(widget.fornecedorParaEditar!.id)
            .update(dados);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fornecedor / Parceiro'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Razão Social / Nome',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _documentoController,
                      decoration: const InputDecoration(
                        labelText: 'CNPJ / CPF',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _contatoController,
                      decoration: const InputDecoration(
                        labelText: 'Contato (Telefone / Email)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Simples campos de texto por enquanto para garantir que roda 100%
                    TextFormField(
                      initialValue: _categoriaSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Classe (ex: Serviços Industriais)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => _categoriaSelecionada = val,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      initialValue: _subcategoriaSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Subclasse (ex: Tinturaria)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => _subcategoriaSelecionada = val,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('GUARDAR FORNECEDOR'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
