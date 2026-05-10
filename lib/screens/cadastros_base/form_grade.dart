import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormGrade extends StatefulWidget {
  const FormGrade({super.key});

  @override
  State<FormGrade> createState() => _FormGradeState();
}

class _FormGradeState extends State<FormGrade> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _tamanhoController = TextEditingController();

  List<String> _tamanhos = [];
  bool _salvando = false;

  void _adicionarTamanho() {
    if (_tamanhoController.text.isNotEmpty) {
      setState(() {
        _tamanhos.add(_tamanhoController.text.toUpperCase());
        _tamanhoController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Grade de Tamanhos'),
        backgroundColor: Colors.white, // Ajustado para o padrão visual do app
        foregroundColor: Colors.blueGrey,
        elevation: 1,
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
                  labelText: 'Nome da Grade (ex: Adulto Masculino)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Informe o nome';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tamanhoController,
                      decoration: const InputDecoration(
                        labelText: 'Adicionar Tamanho (ex: P, M, G, 42)',
                        border: OutlineInputBorder(),
                      ),
                      onFieldSubmitted: (_) => _adicionarTamanho(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blueGrey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: _adicionarTamanho,
                      icon: const Icon(Icons.add, color: Colors.white),
                      tooltip: 'Adicionar à grade',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),
              const Text(
                'Tamanhos adicionados (toque para remover):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),

              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _tamanhos
                    .map(
                      (tam) => ActionChip(
                        label: Text(
                          tam,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.blueGrey.shade50,
                        onPressed: () {
                          setState(() {
                            _tamanhos.remove(tam);
                          });
                        },
                        avatar: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.blueGrey,
                        ),
                      ),
                    )
                    .toList(),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _salvando
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate() &&
                              _tamanhos.isNotEmpty) {
                            setState(() => _salvando = true);

                            try {
                              // GRAVA NA NUVEM FIREBASE (Sem devoluções locais)
                              await FirebaseFirestore.instance
                                  .collection('grades')
                                  .add({
                                    'clienteId': 'teste_textil',
                                    'nome': _nomeController.text.trim(),
                                    'tamanhos': _tamanhos,
                                    'ativo': true,
                                    'dataCadastro':
                                        FieldValue.serverTimestamp(),
                                  });

                              if (mounted) {
                                Navigator.pop(
                                  context,
                                ); // Apenas fecha a tela! O StreamBuilder na tela base faz o resto.
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('ERRO AO SALVAR: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _salvando = false);
                            }
                          } else if (_tamanhos.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Adicione pelo menos um tamanho!',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'CONFIRMAR GRADE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
