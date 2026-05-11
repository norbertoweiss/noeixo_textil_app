import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormFormaPagamento extends StatefulWidget {
  const FormFormaPagamento({super.key});

  @override
  State<FormFormaPagamento> createState() => _FormFormaPagamentoState();
}

class _FormFormaPagamentoState extends State<FormFormaPagamento> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  bool _salvando = false;

  Future<void> _salvar() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _salvando = true);
      try {
        await FirebaseFirestore.instance.collection('formas_pagamento').add({
          'clienteId': 'teste_textil',
          'nome': _nomeController.text.trim(),
          'ativo': true,
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Forma de Pagamento salva!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Forma de Pagamento'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Forma (Ex: Boleto, PIX)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _salvando ? null : _salvar,
                  icon: const Icon(Icons.save),
                  label: _salvando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SALVAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
