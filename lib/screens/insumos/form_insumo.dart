import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

// Importações para os botões "+" de cada atributo
import '../cadastros_base/form_cor.dart';
import '../cadastros_base/form_grade.dart';
import '../cadastros_base/form_unidade_medida.dart';
import '../cadastros_base/tela_arvore_catalogo.dart';

class FormInsumo extends StatefulWidget {
  final DocumentSnapshot? insumoParaEditar;
  const FormInsumo({super.key, this.insumoParaEditar});

  @override
  State<FormInsumo> createState() => _FormInsumoState();
}

class _FormInsumoState extends State<FormInsumo> {
  final _formKey = GlobalKey<FormState>();

  final _custoController = TextEditingController();
  final _estoqueMinimoController = TextEditingController();
  final _observacoesController = TextEditingController();

  // A Estrutura da Árvore (3 Níveis)
  List<DocumentSnapshot> _arvoreCompleta = [];
  List<String> _classes = [];
  List<String> _subclasses = [];
  List<String> _subSubclasses = [];

  String? _classeSelecionada;
  String? _subclasseSelecionada;
  String? _subSubSelecionada;
  String? _unidadeSelecionada;

  // Motor Camaleão (Atributos Dinâmicos)
  List<String> _atributosExigidos = [];
  Map<String, String?> _valoresDinamicos = {};
  Map<String, List<Map<String, dynamic>>> _opcoesDinamicas = {};
  bool _carregandoAtributos = false;

  Uint8List? _imagemBytes;
  final ImagePicker _picker = ImagePicker();
  bool _salvando = false;
  List<DocumentSnapshot> _unidades = [];

  @override
  void initState() {
    super.initState();
    _carregarBases();
  }

  Future<void> _carregarBases() async {
    var unids = await FirebaseFirestore.instance
        .collection('unidades_medida')
        .where('ativo', isEqualTo: true)
        .get();
    var snapArvore = await FirebaseFirestore.instance
        .collection('arvore_catalogo')
        .where('clienteId', isEqualTo: 'teste_textil')
        .where('ativo', isEqualTo: true)
        .get();

    if (mounted) {
      setState(() {
        _unidades = unids.docs;
        _arvoreCompleta = snapArvore.docs;
        _classes =
            _arvoreCompleta.map((e) => e['classe'].toString()).toSet().toList()
              ..sort();
      });

      if (widget.insumoParaEditar != null) {
        final d = widget.insumoParaEditar!.data() as Map<String, dynamic>;
        _custoController.text = (d['custoBase'] ?? '').toString();
        _estoqueMinimoController.text = (d['estoqueMinimo'] ?? '').toString();
        _observacoesController.text = d['observacoes'] ?? '';
        _unidadeSelecionada = d['unidade'];
        _classeSelecionada = d['classe'];

        if (d['imagemBase64'] != null) {
          _imagemBytes = base64Decode(d['imagemBase64']);
        }

        if (_classes.contains(_classeSelecionada)) {
          _atualizarSubclasses(limparAbaixo: false);
          _subclasseSelecionada = d['subclasse'];
          if (_subclasses.contains(_subclasseSelecionada)) {
            _atualizarSubSubclasses(limparAbaixo: false);
            _subSubSelecionada = d['subSubclasse'];
            if (d['atributos'] != null) {
              Map<String, dynamic> attrsMap = d['atributos'];
              _valoresDinamicos = attrsMap.map(
                (key, value) => MapEntry(key, value.toString()),
              );
              _selecionarSubSubclasse(_subSubSelecionada, carregarEdicao: true);
            }
          }
        }
      }
    }
  }

  void _atualizarSubclasses({bool limparAbaixo = true}) {
    _subclasses =
        _arvoreCompleta
            .where((e) => e['classe'] == _classeSelecionada)
            .map((e) => e['subclasse'].toString())
            .toSet()
            .toList()
          ..sort();
    if (limparAbaixo) {
      _subclasseSelecionada = null;
      _atualizarSubSubclasses();
    }
  }

  void _atualizarSubSubclasses({bool limparAbaixo = true}) {
    _subSubclasses =
        _arvoreCompleta
            .where(
              (e) =>
                  e['classe'] == _classeSelecionada &&
                  e['subclasse'] == _subclasseSelecionada,
            )
            .map((e) => e['subSubclasse'].toString())
            .toSet()
            .toList()
          ..sort();
    if (limparAbaixo) {
      _subSubSelecionada = null;
      _atributosExigidos = [];
      _valoresDinamicos.clear();
      setState(() {});
    }
  }

  void _selecionarSubSubclasse(String? val, {bool carregarEdicao = false}) {
    _subSubSelecionada = val;
    if (val != null) {
      var doc = _arvoreCompleta.firstWhere(
        (e) =>
            e['classe'] == _classeSelecionada &&
            e['subclasse'] == _subclasseSelecionada &&
            e['subSubclasse'] == val,
      );
      _atributosExigidos = List<String>.from(doc['atributosExigidos'] ?? []);
      if (!carregarEdicao) _valoresDinamicos.clear();
      _carregarOpcoesAtributos(_atributosExigidos);
    } else {
      _atributosExigidos = [];
      setState(() {});
    }
  }

  Future<void> _carregarOpcoesAtributos(List<String> atributos) async {
    setState(() => _carregandoAtributos = true);

    // CORREÇÃO CRÍTICA: Manter em memória as opções antigas para não apagar outros dropdowns!
    Map<String, List<Map<String, dynamic>>> opcoesAtualizadas = Map.from(
      _opcoesDinamicas,
    );

    for (String attr in atributos) {
      if (attr == 'cores') {
        var snap = await FirebaseFirestore.instance
            .collection('cores')
            .where('clienteId', isEqualTo: 'teste_textil')
            .where('ativo', isEqualTo: true)
            .get();
        // CORREÇÃO DE TIPAGEM ESTREITA AQUI <Map<String, dynamic>>
        opcoesAtualizadas['cores'] = snap.docs
            .map<Map<String, dynamic>>(
              (d) => {'id': d.id, 'nome': '[${d['codigo']}] ${d['nome']}'},
            )
            .toList();
      } else if (attr == 'grades') {
        var snap = await FirebaseFirestore.instance
            .collection('grades')
            .where('clienteId', isEqualTo: 'teste_textil')
            .where('ativo', isEqualTo: true)
            .get();
        opcoesAtualizadas['grades'] = snap.docs
            .map<Map<String, dynamic>>((d) => {'id': d.id, 'nome': d['nome']})
            .toList();
      } else {
        var snap = await FirebaseFirestore.instance
            .collection('tabelas_auxiliares_dados')
            .where('clienteId', isEqualTo: 'teste_textil')
            .where('tabelaId', isEqualTo: attr)
            .where('ativo', isEqualTo: true)
            .get();
        opcoesAtualizadas[attr] = snap.docs
            .map<Map<String, dynamic>>((d) => {'id': d.id, 'nome': d['nome']})
            .toList();
      }
    }

    if (mounted) {
      setState(() {
        _opcoesDinamicas = opcoesAtualizadas;
        _carregandoAtributos = false;
      });
    }
  }

  Future<void> _adicionarNovoItemAtributo(String attr) async {
    if (attr == 'cores') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FormCor()),
      );
    } else if (attr == 'grades') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FormGrade()),
      );
    } else {
      await _mostrarDialogoItemAuxiliar(attr);
    }
    // Atualiza APENAS a lista afetada, sem perder o que já foi preenchido
    await _carregarOpcoesAtributos([attr]);
  }

  Future<void> _mostrarDialogoItemAuxiliar(String tabelaId) async {
    final TextEditingController nomeCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Item', style: TextStyle(color: Colors.indigo)),
        content: TextField(
          controller: nomeCtrl,
          decoration: const InputDecoration(
            labelText: 'Nome da Especificação',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nomeCtrl.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('tabelas_auxiliares_dados')
                    .add({
                      'clienteId': 'teste_textil',
                      'tabelaId': tabelaId,
                      'nome': nomeCtrl.text.trim(),
                      'ativo': true,
                      'dataCriacao': FieldValue.serverTimestamp(),
                    });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );
  }

  // CORREÇÃO DA TELA VERMELHA: Agora a tipagem não irá colapsar com o orElse.
  String get _nomeGerado {
    if (_subSubSelecionada == null) return 'Selecione os atributos abaixo...';
    List<String> partes = [_subSubSelecionada!];

    for (String attr in _atributosExigidos) {
      if (_valoresDinamicos[attr] != null) {
        var opcoesDoAtributo = _opcoesDinamicas[attr] ?? [];
        var obj = opcoesDoAtributo.firstWhere(
          (e) => e['id'].toString() == _valoresDinamicos[attr].toString(),
          orElse: () => <String, dynamic>{'nome': ''},
        );

        if (obj['nome'].toString().isNotEmpty) {
          partes.add(obj['nome'].toString());
        }
      }
    }
    return partes.join(' - ');
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
        setState(() => _imagemBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
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
                    setState(() => _imagemBytes = null);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    for (String attr in _atributosExigidos) {
      if (_valoresDinamicos[attr] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preencha todas as especificações do insumo!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _salvando = true);

    final dados = {
      'clienteId': 'teste_textil',
      'nome': _nomeGerado,
      'classe': _classeSelecionada,
      'subclasse': _subclasseSelecionada,
      'subSubclasse': _subSubSelecionada,
      'atributos': _valoresDinamicos,
      'unidade': _unidadeSelecionada,
      'custoBase':
          double.tryParse(_custoController.text.replaceAll(',', '.')) ?? 0.0,
      'estoqueMinimo':
          double.tryParse(_estoqueMinimoController.text.replaceAll(',', '.')) ??
          0.0,
      'observacoes': _observacoesController.text.trim(),
      'imagemBase64': _imagemBytes != null ? base64Encode(_imagemBytes!) : null,
      'ativo': widget.insumoParaEditar == null
          ? true
          : (widget.insumoParaEditar!['ativo'] ?? true),
      'dataAtualizacao': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.insumoParaEditar == null) {
        dados['estoqueAtual'] = 0.0;
        dados['estoqueComprometido'] = 0.0;
        await FirebaseFirestore.instance.collection('insumos').add(dados);
      } else {
        await FirebaseFirestore.instance
            .collection('insumos')
            .doc(widget.insumoParaEditar!.id)
            .update(dados);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String _formatarNomeCampo(String id) {
    if (id == 'cores') return 'Cor Exata';
    if (id == 'grades') return 'Grade / Tamanho';
    if (id == 'tecidos') return 'Tecido / Malha';
    return 'Especificação ($id)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.insumoParaEditar == null ? 'Novo Insumo' : 'Editar Insumo',
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueGrey,
      ),
      body: _classes.isEmpty || _unidades.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.shade100),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Nome Técnico no Sistema:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.indigo.shade400,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _nomeGerado,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Center(
                      child: GestureDetector(
                        onTap: _mostrarOpcoesImagem,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blueGrey.shade200),
                          ),
                          child: _imagemBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    _imagemBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      color: Colors.blueGrey,
                                      size: 30,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Adicionar Foto',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: '1. Classe',
                              border: OutlineInputBorder(),
                            ),
                            value: _classeSelecionada,
                            isExpanded: true,
                            items: _classes
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() {
                              _classeSelecionada = v;
                              _atualizarSubclasses();
                            }),
                            validator: (v) => v == null ? 'Obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit_note,
                              color: Colors.white,
                            ),
                            tooltip: 'Gerir Árvore',
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const TelaArvoreCatalogo(),
                                ),
                              );
                              _carregarBases();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: '2. Subclasse (A Gaveta)',
                        border: OutlineInputBorder(),
                      ),
                      value: _subclasseSelecionada,
                      isExpanded: true,
                      items: _subclasses
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _subclasseSelecionada = v;
                        _atualizarSubSubclasses();
                      }),
                      validator: (v) => v == null ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: '3. Nome Base (A Folha)',
                        border: OutlineInputBorder(),
                      ),
                      value: _subSubSelecionada,
                      isExpanded: true,
                      items: _subSubclasses
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => _selecionarSubSubclasse(v),
                      validator: (v) => v == null ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 20),

                    if (_carregandoAtributos)
                      const Center(child: CircularProgressIndicator())
                    else if (_atributosExigidos.isNotEmpty) ...[
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Especificações Exigidas',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                      ..._atributosExigidos.map((attr) {
                        List<Map<String, dynamic>> opcoes =
                            _opcoesDinamicas[attr] ?? [];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: _formatarNomeCampo(attr),
                                    border: const OutlineInputBorder(),
                                  ),
                                  value: _valoresDinamicos[attr],
                                  isExpanded: true,
                                  items: opcoes
                                      .map(
                                        (op) => DropdownMenuItem<String>(
                                          value: op['id'].toString(),
                                          child: Text(op['nome'].toString()),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(
                                    () => _valoresDinamicos[attr] = v,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      _adicionarNovoItemAtributo(attr),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(),
                    ],

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Unidade M.',
                              border: OutlineInputBorder(),
                            ),
                            value: _unidadeSelecionada,
                            items: _unidades
                                .map(
                                  (doc) => DropdownMenuItem(
                                    value: doc['sigla'].toString(),
                                    child: Text(
                                      '${doc['nome']} (${doc['sigla']})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _unidadeSelecionada = v),
                            validator: (v) => v == null ? 'Obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _estoqueMinimoController,
                            decoration: const InputDecoration(
                              labelText: 'Estoque Mín.',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _custoController,
                      decoration: const InputDecoration(
                        labelText: 'Custo Atualizado (Base)',
                        border: OutlineInputBorder(),
                        prefixText: 'R\$ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _observacoesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Observações de Lote',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _salvar,
                        child: _salvando
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'SALVAR INSUMO',
                                style: TextStyle(
                                  color: Colors.white,
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
