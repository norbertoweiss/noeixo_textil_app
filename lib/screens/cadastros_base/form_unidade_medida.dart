import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormUnidadeMedida extends StatefulWidget {
  final DocumentSnapshot? unidadeParaEditar;
  const FormUnidadeMedida({super.key, this.unidadeParaEditar});

  @override
  State<FormUnidadeMedida> createState() => _FormUnidadeMedidaState();
}

class _FormUnidadeMedidaState extends State<FormUnidadeMedida> {
  final _formKey = GlobalKey<FormState>();
  final _siglaController = TextEditingController();
  final _nomeController = TextEditingController();
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    if (widget.unidadeParaEditar != null) {
      final d = widget.unidadeParaEditar!.data() as Map<String, dynamic>;
      _siglaController.text = d['sigla'] ?? '';
      _nomeController.text = d['nome'] ?? '';
    }
  }

  @override
  void dispose() {
    _siglaController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    final dados = {
      'sigla': _siglaController.text.trim().toLowerCase(),
      'nome': _nomeController.text.trim(),
      'clienteId': 'teste_textil',
      'ativo': true,
    };

    try {
      if (widget.unidadeParaEditar == null) {
        await FirebaseFirestore.instance
            .collection('unidades_medida')
            .add(dados);
      } else {
        await FirebaseFirestore.instance
            .collection('unidades_medida')
            .doc(widget.unidadeParaEditar!.id)
            .update(dados);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar unidade: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.unidadeParaEditar == null ? 'Nova Unidade' : 'Editar Unidade',
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueGrey,
        elevation: 1,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _siglaController,
                      decoration: const InputDecoration(
                        labelText: 'Sigla (ex: m, kg, un)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome Extenso (ex: Metro, Quilograma)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: _salvar,
                        child: const Text(
                          'CONFIRMAR UNIDADE',
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
