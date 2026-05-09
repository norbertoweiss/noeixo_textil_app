import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NOVO: Motor do banco de dados
import '../../models/grade_model.dart';

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
  bool _salvando = false; // NOVO: Controle da rodinha de carregamento

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
        backgroundColor: Colors.blueGrey,
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
                  labelText: 'Nome da Grade (ex: Adulto Masculino)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Informe o nome';
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
                        labelText: 'Adicionar Tamanho (ex: P)',
                        border: OutlineInputBorder(),
                      ),
                      onFieldSubmitted: (_) => _adicionarTamanho(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _adicionarTamanho,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Text(
                'Tamanhos adicionados (clique para remover):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _tamanhos
                    .map(
                      (tam) => ActionChip(
                        label: Text(tam),
                        onPressed: () {
                          setState(() {
                            _tamanhos.remove(tam);
                          });
                        },
                        avatar: const Icon(Icons.close, size: 14),
                      ),
                    )
                    .toList(),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _salvando
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate() &&
                              _tamanhos.isNotEmpty) {
                            setState(() {
                              _salvando = true;
                            });

                            try {
                              final db = FirebaseFirestore.instance;
                              String idFinal = db.collection('grades').doc().id;

                              // GRAVA NA NUVEM FIREBASE
                              await db.collection('grades').doc(idFinal).set({
                                'id': idFinal,
                                'clienteId': 'teste_textil',
                                'nome': _nomeController.text,
                                'tamanhos': _tamanhos,
                                'ativo': true,
                              });

                              // Prepara o retorno para a lista local
                              final novaGrade = GradeModel(
                                id: idFinal,
                                clienteId: 'teste_textil',
                                nome: _nomeController.text,
                                tamanhos: _tamanhos,
                                ativo: true,
                              );

                              if (mounted) {
                                Navigator.pop(context, novaGrade);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Grade salva na nuvem com sucesso!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
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
                              if (mounted) {
                                setState(() {
                                  _salvando = false;
                                });
                              }
                            }
                          } else if (_tamanhos.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Adicione pelo menos um tamanho'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                  ),
                  child: _salvando
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'GUARDAR GRADE',
                          style: TextStyle(
                            color: Colors.white,
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
