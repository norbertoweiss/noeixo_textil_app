import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'tela_ficha_tecnica_main.dart';

class AbaQualidade extends StatefulWidget {
  final TelaFichaTecnicaMainState controller;

  const AbaQualidade({super.key, required this.controller});

  @override
  State<AbaQualidade> createState() => _AbaQualidadeState();
}

class _AbaQualidadeState extends State<AbaQualidade> {
  bool _carregandoBase = true;
  List<Map<String, dynamic>> _parametrosQualidadeBase = [];
  List<Map<String, dynamic>> _listaSetores = [];
  List<Map<String, dynamic>> _listaUnidades = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosBase();
  }

  Future<void> _carregarDadosBase() async {
    setState(() => _carregandoBase = true);
    try {
      final qualidadeSnap = await FirebaseFirestore.instance
          .collection('parametros_qualidade')
          .where('ativo', isEqualTo: true)
          .get();
      final setoresSnap = await FirebaseFirestore.instance
          .collection('setores_industria')
          .orderBy('nome')
          .get();
      final unidadesSnap = await FirebaseFirestore.instance
          .collection('unidades_medida')
          .get();

      setState(() {
        _parametrosQualidadeBase = qualidadeSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _listaSetores = setoresSnap.docs
            .map((d) => {'id': d.id, 'nome': d['nome']})
            .toList();
        _listaUnidades = unidadesSnap.docs
            .map((d) => {'id': d.id, 'nome': d['sigla'] ?? d['nome']})
            .toList();
        _carregandoBase = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar base de qualidade: $e')),
        );
      }
      setState(() => _carregandoBase = false);
    }
  }

  void _modalNovoCadastroRapido(String colecao, String titulo, String hint) {
    String novoNome = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nome / Sigla',
            hintText: hint,
          ),
          onChanged: (v) => novoNome = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (novoNome.trim().isNotEmpty) {
                try {
                  Map<String, dynamic> dadosCadastro = {
                    'nome': novoNome.trim(),
                    'criadoEm': FieldValue.serverTimestamp(),
                  };
                  if (colecao == 'unidades_medida') {
                    dadosCadastro['sigla'] = novoNome.trim().toUpperCase();
                    dadosCadastro['ativo'] = true;
                  }
                  if (colecao == 'parametros_qualidade') {
                    dadosCadastro['etapa'] = 'Produção';
                    dadosCadastro['ativo'] = true;
                  }
                  await FirebaseFirestore.instance
                      .collection(colecao)
                      .add(dadosCadastro);

                  if (mounted) Navigator.pop(context);
                  _carregarDadosBase(); // Recarrega as listas

                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$titulo criado!')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                  }
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _modalAdicionarQualidade({int? indexEdicao}) {
    String parametro = '';
    String? setorSelecionadoId;
    String? unidadeSelecionadaId;
    final TextEditingController valorCtrl = TextEditingController();
    final TextEditingController toleranciaCtrl = TextEditingController();
    final TextEditingController obsCtrl = TextEditingController();
    String? fotoBase64;

    if (indexEdicao != null) {
      final item = widget.controller.itensQualidade[indexEdicao];
      parametro = item['parametro']?.toString() ?? '';
      setorSelecionadoId = item['setorId'];
      unidadeSelecionadaId = item['unidadeId'];
      valorCtrl.text = item['valor']?.toString() ?? '';
      toleranciaCtrl.text = item['tolerancia']?.toString() ?? '';
      obsCtrl.text = item['observacao']?.toString() ?? '';
      fotoBase64 = item['fotoBase64'];
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            indexEdicao == null ? 'Novo Item de Qualidade' : 'Editar Qualidade',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Autocomplete<Map<String, dynamic>>(
                          initialValue: TextEditingValue(text: parametro),
                          displayStringForOption: (option) =>
                              option['nome'].toString(),
                          optionsBuilder: (v) {
                            if (v.text.isEmpty) {
                              return const Iterable<
                                Map<String, dynamic>
                              >.empty();
                            }
                            return _parametrosQualidadeBase.where(
                              (p) => p['nome']
                                  .toString()
                                  .toLowerCase()
                                  .contains(v.text.toLowerCase()),
                            );
                          },
                          onSelected: (s) => parametro = s['nome'].toString(),
                          fieldViewBuilder: (ctx, ctrl, focus, submit) =>
                              TextFormField(
                                controller: ctrl,
                                focusNode: focus,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Parâmetro (Ex: Tensão, Pontos/cm)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () => _modalNovoCadastroRapido(
                            'parametros_qualidade',
                            'Novo Parâmetro',
                            'Ex: Bainha, Pontos',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value:
                              _listaSetores.any(
                                (s) => s['id'] == setorSelecionadoId,
                              )
                              ? setorSelecionadoId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Setor de Conferência',
                            border: OutlineInputBorder(),
                          ),
                          items: _listaSetores
                              .map(
                                (s) => DropdownMenuItem<String>(
                                  value: s['id'],
                                  child: Text(s['nome']),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setModalState(() => setorSelecionadoId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () => _modalNovoCadastroRapido(
                            'setores_industria',
                            'Novo Setor',
                            'Ex: Tecelagem, Facção',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: valorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Valor Esperado',
                            border: OutlineInputBorder(),
                            hintText: 'Ex: 30/1, 3, 15',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value:
                              _listaUnidades.any(
                                (u) => u['id'] == unidadeSelecionadaId,
                              )
                              ? unidadeSelecionadaId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Unidade',
                            border: OutlineInputBorder(),
                          ),
                          items: _listaUnidades
                              .map(
                                (u) => DropdownMenuItem<String>(
                                  value: u['id'],
                                  child: Text(u['nome']),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setModalState(() => unidadeSelecionadaId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () => _modalNovoCadastroRapido(
                            'unidades_medida',
                            'Nova Unidade',
                            'Ex: cm, %, agulhas',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: toleranciaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tolerância (+/-)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: obsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Observação / Instrução',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Repositório Visual (Em breve: edição com setas)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (fotoBase64 != null && fotoBase64!.isNotEmpty)
                    Image.memory(base64Decode(fotoBase64!), height: 120),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.teal),
                        onPressed: () async {
                          final img = await ImagePicker().pickImage(
                            source: ImageSource.camera,
                            imageQuality: 50,
                          );
                          if (img != null) {
                            final bytes = await img.readAsBytes();
                            setModalState(
                              () => fotoBase64 = base64Encode(bytes),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.photo_library,
                          color: Colors.teal,
                        ),
                        onPressed: () async {
                          final img = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 50,
                          );
                          if (img != null) {
                            final bytes = await img.readAsBytes();
                            setModalState(
                              () => fotoBase64 = base64Encode(bytes),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final novoItem = {
                  'parametro': parametro.isEmpty
                      ? 'Parâmetro Não Informado'
                      : parametro,
                  'setorId': setorSelecionadoId,
                  'setorNome': setorSelecionadoId != null
                      ? _listaSetores.firstWhere(
                          (s) => s['id'] == setorSelecionadoId,
                        )['nome']
                      : null,
                  'unidadeId': unidadeSelecionadaId,
                  'unidadeNome': unidadeSelecionadaId != null
                      ? _listaUnidades.firstWhere(
                          (u) => u['id'] == unidadeSelecionadaId,
                        )['nome']
                      : null,
                  'valor': valorCtrl.text,
                  'tolerancia': toleranciaCtrl.text,
                  'observacao': obsCtrl.text,
                  'fotoBase64': fotoBase64,
                };

                setState(() {
                  if (indexEdicao == null) {
                    widget.controller.itensQualidade.add(novoItem);
                  } else {
                    widget.controller.itensQualidade[indexEdicao] = novoItem;
                  }
                });
                widget.controller.registrarAlteracao();
                Navigator.pop(context);
              },
              child: const Text('Confirmar Requisito'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoBase) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {
              if (widget.controller.tamanhosGrade.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Selecione uma Grade na Aba Identificação primeiro!',
                    ),
                  ),
                );
                return;
              }
              _modalAdicionarQualidade();
            },
            icon: const Icon(Icons.add_task),
            label: const Text('Adicionar Requisito de Qualidade'),
          ),
        ),
        Expanded(
          child: widget.controller.itensQualidade.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum requisito adicionado.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: widget.controller.itensQualidade.length,
                  itemBuilder: (context, index) {
                    final item = widget.controller.itensQualidade[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading:
                            item['fotoBase64'] != null &&
                                item['fotoBase64'].toString().isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(
                                  base64Decode(item['fotoBase64'].toString()),
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                        title: Text(
                          '${item['parametro']} (${item['valor']} ${item['unidadeNome'] ?? ''})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tolerância: ${item['tolerancia']} | Setor: ${item['setorNome'] ?? 'Não definido'}',
                            ),
                            if (item['observacao'] != null &&
                                item['observacao'].toString().isNotEmpty)
                              Text(
                                'Obs: ${item['observacao']}',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.orange,
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            setState(() {
                              widget.controller.itensQualidade.removeAt(index);
                            });
                            widget.controller.registrarAlteracao();
                          },
                        ),
                        onTap: () =>
                            _modalAdicionarQualidade(indexEdicao: index),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
