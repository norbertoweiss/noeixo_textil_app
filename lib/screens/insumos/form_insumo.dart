import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // NOVO: Pacote da câmara importado
import '../fornecedores/form_categoria_fornecedor.dart';

class FormInsumo extends StatefulWidget {
  final DocumentSnapshot? insumoParaEditar;
  const FormInsumo({super.key, this.insumoParaEditar});

  @override
  State<FormInsumo> createState() => _FormInsumoState();
}

class _FormInsumoState extends State<FormInsumo> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _custoController = TextEditingController();
  final _estoqueMinimoController = TextEditingController();
  final _observacoesController = TextEditingController();

  String? _classeSelecionada;
  String? _subclasseSelecionada;
  String? _unidadeSelecionada;

  // NOVO: Variáveis para gerir a imagem igual ao form_cor
  Uint8List? _imagemBytes;
  final ImagePicker _picker = ImagePicker();

  bool _salvando = false;

  List<DocumentSnapshot> _classes = [];
  List<DocumentSnapshot> _unidades = [];
  List<String> _subclassesAtuais = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosMestres();
    if (widget.insumoParaEditar != null) {
      final d = widget.insumoParaEditar!.data() as Map<String, dynamic>;
      _nomeController.text = d['nome'] ?? '';
      _custoController.text = (d['custoBase'] ?? '').toString();
      _estoqueMinimoController.text = (d['estoqueMinimo'] ?? '').toString();
      _observacoesController.text = d['observacoes'] ?? '';
      _classeSelecionada = d['classe'];
      _subclasseSelecionada = d['subclasse'];
      _unidadeSelecionada = d['unidade'];

      // Carrega a imagem da nuvem e converte de volta para Bytes
      if (d['imagemBase64'] != null) {
        _imagemBytes = base64Decode(d['imagemBase64']);
      }
    }
  }

  Future<void> _carregarDadosMestres() async {
    var unids = await FirebaseFirestore.instance
        .collection('unidades_medida')
        .where('ativo', isEqualTo: true)
        .get();
    var cats = await FirebaseFirestore.instance
        .collection('categorias_fornecedor')
        .where('ativo', isEqualTo: true)
        .get();

    if (mounted) {
      setState(() {
        _unidades = unids.docs;
        _classes = cats.docs;
        _classes.sort(
          (a, b) => a['nome'].toString().toLowerCase().compareTo(
            b['nome'].toString().toLowerCase(),
          ),
        );
        if (_classeSelecionada != null)
          _atualizarSubclasses(_classeSelecionada!);
      });
    }
  }

  void _atualizarSubclasses(String classeNome) {
    try {
      var catDoc = _classes.firstWhere((doc) => doc['nome'] == classeNome);
      var subList = catDoc['subgrupos'] ?? [];
      setState(() {
        _subclassesAtuais = subList
            .map<String>((e) => e is Map ? e['nome'].toString() : e.toString())
            .toList();
        if (!_subclassesAtuais.contains(_subclasseSelecionada))
          _subclasseSelecionada = null;
      });
    } catch (e) {
      setState(() {
        _subclassesAtuais = [];
        _subclasseSelecionada = null;
      });
    }
  }

  // ==========================================
  // LÓGICA DE CAPTURA DE IMAGEM
  // ==========================================
  Future<void> _pegarImagem(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 500, // Compressão inteligente
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar imagem: $e'),
            backgroundColor: Colors.red,
          ),
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
  // ==========================================

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final dados = {
      'clienteId': 'teste_textil',
      'nome': _nomeController.text.trim(),
      'classe': _classeSelecionada,
      'subclasse': _subclasseSelecionada,
      'unidade': _unidadeSelecionada,
      'custoBase':
          double.tryParse(_custoController.text.replaceAll(',', '.')) ?? 0.0,
      'estoqueMinimo':
          double.tryParse(_estoqueMinimoController.text.replaceAll(',', '.')) ??
          0.0,
      'observacoes': _observacoesController.text.trim(),
      'imagemBase64': _imagemBytes != null
          ? base64Encode(_imagemBytes!)
          : null, // Converte para a nuvem
      'ativo': widget.insumoParaEditar == null
          ? true
          : (widget.insumoParaEditar!['ativo'] ?? true),
      'dataAtualizacao': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.insumoParaEditar == null) {
        await FirebaseFirestore.instance.collection('insumos').add(dados);
      } else {
        await FirebaseFirestore.instance
            .collection('insumos')
            .doc(widget.insumoParaEditar!.id)
            .update(dados);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
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
                    // --- CAIXA DE IMAGEM CLICÁVEL ---
                    Center(
                      child: GestureDetector(
                        onTap:
                            _mostrarOpcoesImagem, // Abre as opções de Câmera/Galeria
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
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText:
                            'Descrição do Insumo (ex: Fio Poliéster 120)',
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
                              labelText: 'Classe',
                              border: OutlineInputBorder(),
                            ),
                            value: _classeSelecionada,
                            isExpanded: true,
                            items: _classes
                                .map(
                                  (doc) => DropdownMenuItem(
                                    value: doc['nome'].toString(),
                                    child: Text(doc['nome'].toString()),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _classeSelecionada = v;
                                _atualizarSubclasses(v!);
                              });
                            },
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
                            icon: const Icon(Icons.add, color: Colors.white),
                            tooltip: 'Adicionar Nova Classe/Subclasse',
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const FormCategoriaFornecedor(),
                                ),
                              );
                              _carregarDadosMestres();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Subclasse',
                        border: OutlineInputBorder(),
                      ),
                      value: _subclasseSelecionada,
                      isExpanded: true,
                      items: _subclassesAtuais
                          .map(
                            (nome) => DropdownMenuItem(
                              value: nome,
                              child: Text(nome),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _subclasseSelecionada = v),
                    ),
                    const SizedBox(height: 16),

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
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Observações de Lote, Testes ou Qualidade',
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
