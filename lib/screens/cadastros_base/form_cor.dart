import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cor_model.dart';

class FormCor extends StatefulWidget {
  final CorModel? corParaEditar;

  const FormCor({super.key, this.corParaEditar});

  @override
  State<FormCor> createState() => _FormCorState();
}

class _FormCorState extends State<FormCor> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();

  Uint8List? _imagemBytes;
  final ImagePicker _picker = ImagePicker();

  bool _editando = false;
  bool _gerarCodigoAutomatico = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    if (widget.corParaEditar != null) {
      _editando = true;
      _codigoController.text = widget.corParaEditar!.codigo;
      _nomeController.text = widget.corParaEditar!.nome;
      _imagemBytes = widget.corParaEditar!.imagemBytes;
      _gerarCodigoAutomatico = false;
    }
  }

  Future<void> _pegarImagem(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final Uint8List bytes = await pickedFile.readAsBytes();
        setState(() {
          _imagemBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao selecionar imagem: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarOpcoesImagem() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeria de Fotos'),
                onTap: () {
                  Navigator.pop(context);
                  _pegarImagem(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tirar Foto (Câmera)'),
                onTap: () {
                  Navigator.pop(context);
                  _pegarImagem(ImageSource.camera);
                },
              ),
              if (_imagemBytes != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Remover Imagem',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _imagemBytes = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar Cor' : 'Nova Cor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _mostrarOpcoesImagem,
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _imagemBytes != null
                      ? MemoryImage(_imagemBytes!)
                      : null,
                  child: _imagemBytes == null
                      ? const Icon(
                          Icons.add_a_photo,
                          size: 50,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text(
                  'Gerar Código Automático',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Sequencial: 001, 002...'),
                value: _gerarCodigoAutomatico,
                activeColor: Colors.blueGrey,
                onChanged: _editando
                    ? null
                    : (bool value) {
                        setState(() {
                          _gerarCodigoAutomatico = value;
                          if (value) _codigoController.clear();
                        });
                      },
              ),
              Row(
                children: [
                  if (!_gerarCodigoAutomatico) ...[
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _codigoController,
                        decoration: const InputDecoration(
                          labelText: 'Cód. Manual',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Cor',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Informe o nome'
                          : null,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _salvando
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              _salvando = true;
                            });
                            try {
                              final db = FirebaseFirestore.instance;
                              String codigoFinal = _codigoController.text
                                  .trim();

                              if (_gerarCodigoAutomatico) {
                                final querySnapshot = await db
                                    .collection('cores')
                                    .where(
                                      'clienteId',
                                      isEqualTo: 'teste_textil',
                                    )
                                    .get();
                                int maiorCodigo = 0;
                                for (var doc in querySnapshot.docs) {
                                  final codStr =
                                      doc.data()['codigo'] as String?;
                                  if (codStr != null) {
                                    final codInt = int.tryParse(codStr);
                                    if (codInt != null && codInt > maiorCodigo)
                                      maiorCodigo = codInt;
                                  }
                                }
                                codigoFinal = (maiorCodigo + 1)
                                    .toString()
                                    .padLeft(3, '0');
                              }

                              String idFinal = _editando
                                  ? widget.corParaEditar!.id
                                  : db.collection('cores').doc().id;
                              String? img64 = _imagemBytes != null
                                  ? base64Encode(_imagemBytes!)
                                  : null;

                              await db.collection('cores').doc(idFinal).set({
                                'id': idFinal,
                                'clienteId': 'teste_textil',
                                'codigo': codigoFinal,
                                'nome': _nomeController.text,
                                'ativo': _editando
                                    ? widget.corParaEditar!.ativo
                                    : true,
                                'imagemBase64': img64,
                              });

                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erro: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                            } finally {
                              if (mounted)
                                setState(() {
                                  _salvando = false;
                                });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                  ),
                  child: _salvando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_editando ? 'ATUALIZAR' : 'GUARDAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
