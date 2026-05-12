import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormProduto extends StatefulWidget {
  final String? produtoId;
  final Map<String, dynamic>? dadosAtuais;

  const FormProduto({Key? key, this.produtoId, this.dadosAtuais})
    : super(key: key);

  @override
  _FormProdutoState createState() => _FormProdutoState();
}

class _FormProdutoState extends State<FormProduto> {
  final _formKey = GlobalKey<FormState>();
  final CollectionReference _produtosRef = FirebaseFirestore.instance
      .collection('produtos');

  late TextEditingController _nomeController;
  late TextEditingController _referenciaController;
  late TextEditingController _descricaoController;

  String? _tipoSelecionado;
  bool _isLoading = false;

  final List<String> _tiposProduto = [
    'Produto Intermediário', // A Peça Pai
    'Produto Acabado', // A Peça Filha
  ];

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.dadosAtuais?['nome'] ?? '',
    );
    _referenciaController = TextEditingController(
      text: widget.dadosAtuais?['referencia'] ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.dadosAtuais?['descricao'] ?? '',
    );

    _tipoSelecionado = widget.dadosAtuais?['tipo'];
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _referenciaController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _salvarProduto() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final dadosProduto = {
      'nome': _nomeController.text.trim(),
      'referencia': _referenciaController.text.trim(),
      'descricao': _descricaoController.text.trim(),
      'tipo': _tipoSelecionado,
      'atualizadoEm': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.produtoId == null) {
        // Novo registro
        dadosProduto['criadoEm'] = FieldValue.serverTimestamp();
        await _produtosRef.add(dadosProduto);
      } else {
        // Atualização
        await _produtosRef.doc(widget.produtoId).update(dadosProduto);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto salvo com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar produto: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.produtoId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Editar Produto' : 'Novo Produto')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Campo: Referência / Código
                    TextFormField(
                      controller: _referenciaController,
                      decoration: const InputDecoration(
                        labelText: 'Referência / Código',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Informe a referência'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Campo: Nome do Produto
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Produto',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Informe o nome do produto'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Dropdown: Tipo de Produto (Arquitetura Chave)
                    DropdownButtonFormField<String>(
                      value: _tipoSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Produto',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_tree),
                      ),
                      items: _tiposProduto.map((tipo) {
                        return DropdownMenuItem(value: tipo, child: Text(tipo));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _tipoSelecionado = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Selecione o tipo do produto' : null,
                    ),
                    const SizedBox(height: 16),

                    // Campo: Descrição
                    TextFormField(
                      controller: _descricaoController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (Opcional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botão Salvar
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'Salvar Produto',
                        style: TextStyle(fontSize: 16),
                      ),
                      onPressed: _salvarProduto,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
