import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormCondicaoPagamento extends StatefulWidget {
  const FormCondicaoPagamento({super.key});

  @override
  State<FormCondicaoPagamento> createState() => _FormCondicaoPagamentoState();
}

class _FormCondicaoPagamentoState extends State<FormCondicaoPagamento> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _intervaloController = TextEditingController(text: '30');

  String _unidadeTempo = 'Dias'; // Pode ser Dias, Meses ou Anos
  bool _salvando = false;

  Future<void> _salvar() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _salvando = true);
      try {
        await FirebaseFirestore.instance.collection('condicoes_pagamento').add({
          'clienteId': 'teste_textil',
          'nome': _nomeController.text.trim(),
          'unidadeTempo': _unidadeTempo,
          'intervalo': int.parse(_intervaloController.text),
          'ativo': true,
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Condição salva!'),
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
        title: const Text('Nova Condição de Pagamento'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ex: Para criar a regra "Mensal", coloque Unidade = Meses e Intervalo = 1. A quantidade de parcelas será informada apenas na hora de lançar a nota.',
                  style: TextStyle(color: Colors.teal),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (Ex: Mensal, A cada 15 dias, À Vista)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Unidade de Tempo',
                        border: OutlineInputBorder(),
                      ),
                      value: _unidadeTempo,
                      items: ['Dias', 'Meses', 'Anos'].map((String valor) {
                        return DropdownMenuItem<String>(
                          value: valor,
                          child: Text(valor),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _unidadeTempo = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _intervaloController,
                      decoration: const InputDecoration(
                        labelText: 'Intervalo (Pular de quanto em quanto?)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
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
                  onPressed: _salvando ? null : _salvar,
                  icon: const Icon(Icons.save),
                  label: _salvando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SALVAR CONDIÇÃO'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
