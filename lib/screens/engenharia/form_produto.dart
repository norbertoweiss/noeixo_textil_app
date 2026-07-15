import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class FormProduto extends StatefulWidget {
  final String empresaId;
  final String? produtoId;
  final Map<String, dynamic>? dadosAtuais;

  const FormProduto({
    Key? key,
    required this.empresaId,
    this.produtoId,
    this.dadosAtuais,
  }) : super(key: key);

  @override
  _FormProdutoState createState() => _FormProdutoState();
}

class _FormProdutoState extends State<FormProduto> {
  final _formKey = GlobalKey<FormState>();
  final CollectionReference _produtosRef = FirebaseFirestore.instance
      .collection('produtos');

  late TextEditingController _nomeController;
  late TextEditingController _referenciaController;
  late TextEditingController _descricaoController;

  String? _tipoSelecionado;
  String? _categoriaSelecionada; // <-- NOVO CAMPO DE CATEGORIA
  bool _isLoading = false;

  // --- MÓDULO FOTOGRÁFICO ---
  Uint8List? _imagemBytes;
  final ImagePicker _picker = ImagePicker();

  final List<String> _tiposProduto = [
    'Produto Intermediário',
    'Produto Acabado',
  ];

  // --- CONTROLO DA TABELA DINÂMICA DE CATEGORIAS ---
  String? _tabelaCategoriaId;
  bool _isLoadingCategoriaConfig = true;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.dadosAtuais?['nome'] ?? '',
    );
    _referenciaController = TextEditingController(
      text: widget.dadosAtuais?['referencia'] ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.dadosAtuais?['descricao'] ?? '',
    );

    _tipoSelecionado = widget.dadosAtuais?['tipo'];
    _categoriaSelecionada =
        widget.dadosAtuais?['categoria']; // Recupera a categoria se for edição

    // Recuperar a foto existente, se houver
    if (widget.dadosAtuais != null &&
        widget.dadosAtuais!['fotoBase64'] != null) {
      try {
        _imagemBytes = base64Decode(widget.dadosAtuais!['fotoBase64']);
      } catch (e) {
        debugPrint('Erro ao descodificar imagem antiga: $e');
      }
    }

    _buscarIdTabelaCategoria();
  }

  // =========================================================================
  // CAÇA AO ID DA TABELA "CATEGORIA"
  // =========================================================================
  Future<void> _buscarIdTabelaCategoria() async {
    try {
      // Procura a tabela de configuração que você acabou de criar no motor
      var query = await FirebaseFirestore.instance
          .collection('tabelas_auxiliares_config')
          .where(
            'clienteId',
            isEqualTo: 'teste_textil',
          ) // Respeita o seu padrão atual
          .get();

      for (var doc in query.docs) {
        String titulo = doc['titulo'].toString().toLowerCase().trim();
        // Cobre tanto "Categoria" quanto "Categorias"
        if (titulo == 'categoria' || titulo == 'categorias') {
          _tabelaCategoriaId = doc.id;
          break;
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar config da categoria: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCategoriaConfig = false);
    }
  }

  // =========================================================================
  // GESTÃO DE IMAGENS (CÂMARA / GALERIA) COM COMPRESSÃO
  // =========================================================================
  Future<void> _pegarImagem(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        final Uint8List bytes = await pickedFile.readAsBytes();
        setState(() => _imagemBytes = bytes);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao capturar imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  void _mostrarOpcoesImagem() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blueGrey),
                title: const Text('Tirar Foto (Câmara)'),
                onTap: () {
                  Navigator.pop(context);
                  _pegarImagem(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Colors.blueGrey,
                ),
                title: const Text('Procurar na Galeria'),
                onTap: () {
                  Navigator.pop(context);
                  _pegarImagem(ImageSource.gallery);
                },
              ),
              if (_imagemBytes != null)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
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

  // =========================================================================
  // SALVAR PRODUTO NO FIRESTORE
  // =========================================================================
  Future<void> _salvarProduto() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final dadosProduto = {
          'empresa_id': widget.empresaId,
          'nome': _nomeController.text.trim(),
          'referencia': _referenciaController.text.trim(),
          'tipo': _tipoSelecionado,
          'categoria':
              _categoriaSelecionada ??
              'Sem Categoria', // <-- APLICA A CATEGORIA OFICIAL
          'descricao': _descricaoController.text.trim(),
          'fotoBase64': _imagemBytes != null
              ? base64Encode(_imagemBytes!)
              : null,
          'atualizadoEm': FieldValue.serverTimestamp(),
        };

        if (widget.produtoId == null) {
          dadosProduto['criadoEm'] = FieldValue.serverTimestamp();
          await _produtosRef.add(dadosProduto);
        } else {
          await _produtosRef.doc(widget.produtoId).update(dadosProduto);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produto salvo com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar produto: $e'),
              backgroundColor: Colors.red,
            ),
          );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // =========================================================================
  // O NOVO WIDGET DINÂMICO DO DROPDOWN DE CATEGORIA
  // =========================================================================
  Widget _construirDropdownCategoria() {
    if (_isLoadingCategoriaConfig) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: LinearProgressIndicator(),
      );
    }

    if (_tabelaCategoriaId == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Tabela de "Categoria" não encontrada nos Cadastros Base. Crie-a primeiro.',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tabelas_auxiliares_dados')
          .where('clienteId', isEqualTo: 'teste_textil')
          .where('tabelaId', isEqualTo: _tabelaCategoriaId)
          .where('ativo', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const LinearProgressIndicator();

        List<DropdownMenuItem<String>> itens = [];
        if (snapshot.hasData) {
          var docs = snapshot.data!.docs;
          // Ordena alfabeticamente a lista para facilitar a vida do operador
          docs.sort(
            (a, b) => (a['nome'] ?? '').toString().compareTo(
              (b['nome'] ?? '').toString(),
            ),
          );

          for (var doc in docs) {
            String nomeCat = doc['nome'];
            itens.add(DropdownMenuItem(value: nomeCat, child: Text(nomeCat)));
          }
        }

        // Se o produto for antigo e tiver uma categoria que foi apagada, garante que o dropdown não quebre
        if (_categoriaSelecionada != null &&
            _categoriaSelecionada != 'Sem Categoria' &&
            !itens.any((item) => item.value == _categoriaSelecionada)) {
          itens.add(
            DropdownMenuItem(
              value: _categoriaSelecionada,
              child: Text('$_categoriaSelecionada (Inativa)'),
            ),
          );
        }

        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Categoria do Produto *',
            border: OutlineInputBorder(),
          ),
          value: _categoriaSelecionada == 'Sem Categoria'
              ? null
              : _categoriaSelecionada,
          items: itens,
          onChanged: (value) => setState(() => _categoriaSelecionada = value),
          validator: (value) => value == null || value.isEmpty
              ? 'Selecione uma categoria válida'
              : null,
        );
      },
    );
  }

  // =========================================================================
  // INTERFACE
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.produtoId == null ? 'Novo Produto' : 'Editar Produto',
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- ÁREA DA FOTOGRAFIA ---
                    Center(
                      child: GestureDetector(
                        onTap: _mostrarOpcoesImagem,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blueGrey.shade200,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _imagemBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
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
                                      size: 40,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Adicionar Foto\n(Catálogo)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.blueGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- CAMPOS DO FORMULÁRIO ---
                    TextFormField(
                      controller: _referenciaController,
                      decoration: const InputDecoration(
                        labelText: 'Referência / Código *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'A referência é obrigatória'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Produto *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'O nome é obrigatório'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // --- O NOVO DROPDOWN MÁGICO ---
                    _construirDropdownCategoria(),

                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Produto *',
                        border: OutlineInputBorder(),
                      ),
                      value: _tipoSelecionado,
                      items: _tiposProduto
                          .map(
                            (tipo) => DropdownMenuItem(
                              value: tipo,
                              child: Text(tipo),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _tipoSelecionado = value),
                      validator: (value) =>
                          value == null ? 'Selecione o tipo do produto' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descricaoController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (Opcional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'Salvar Produto',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _salvarProduto,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
