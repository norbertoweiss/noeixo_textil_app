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
  final _qtdParcelasController = TextEditingController(text: '1');
  final _primeiroVencimentoController = TextEditingController(text: '0');
  final _intervaloController = TextEditingController(text: '0');

  bool _salvando = false;

  Future<void> _salvar() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _salvando = true);
      try {
        await FirebaseFirestore.instance.collection('condicoes_pagamento').add({
          'clienteId': 'teste_textil',
          'nome': _nomeController.text.trim(),
          'qtd_parcelas': int.parse(_qtdParcelasController.text),
          'dias_primeiro_vencimento': int.parse(
            _primeiroVencimentoController.text,
          ),
          'intervalo_dias': int.parse(_intervaloController.text),
          'ativo': true,
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Condição de Pagamento salva com sucesso!'),
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
        backgroundColor:
            Colors.orange.shade700, // Ajustado para a cor financeira
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
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Como configurar de forma dinâmica:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• À Vista: Parcelas = 1 | 1º Vencimento = 0'),
                    Text(
                      '• 30/60/90: Parcelas = 3 | 1º Vencimento = 30 | Intervalo = 30',
                    ),
                    Text(
                      '• Entrada + 30/60: Parcelas = 3 | 1º Vencimento = 0 | Intervalo = 30',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText:
                      'Nome Comercial (O que o vendedor vai ler. Ex: 30/60/90 Dias)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtdParcelasController,
                      decoration: const InputDecoration(
                        labelText: 'Nº de Parcelas',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _primeiroVencimentoController,
                      decoration: const InputDecoration(
                        labelText: '1º Vencimento (Dias)',
                        hintText: '0 = No Faturamento',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _intervaloController,
                      decoration: const InputDecoration(
                        labelText: 'Intervalo (Dias)',
                        hintText: 'Ex: 30',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sync),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _salvando ? null : _salvar,
                  icon: const Icon(Icons.save),
                  label: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'SALVAR REGRA MATEMÁTICA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
