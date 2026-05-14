import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

class FormProcesso extends StatefulWidget {
  final String? processoId;
  final Map<String, dynamic>? dadosAtuais;

  const FormProcesso({super.key, this.processoId, this.dadosAtuais});

  @override
  State<FormProcesso> createState() => _FormProcessoState();
}

class _FormProcessoState extends State<FormProcesso> {
  final _formKey = GlobalKey<FormState>();

  String _nomeOperacao = '';
  String _tipo = 'Interno';
  bool _isLoading = false;
  String _statusCarregamento = '';

  double _custoExterno = 0.0;

  // --- CONTROLES DE TEMPO (MINUTOS E SEGUNDOS) ---
  final TextEditingController _minutosCtrl = TextEditingController();
  final TextEditingController _segundosCtrl = TextEditingController();

  String? _setorSelecionadoId;
  String? _setorSelecionadoNome;
  String? _maquinaSelecionadaId;
  String? _maquinaSelecionadaNome;
  String? _unidadeExternaId;
  String? _unidadeExternaNome;

  String? _imagemBase64;

  File? _videoLocalFile;
  String? _videoUrlFirebase;
  VideoPlayerController? _videoController;

  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _listaSetores = [];
  List<Map<String, dynamic>> _listaMaquinas = [];
  List<Map<String, dynamic>> _listaUnidades = [];

  @override
  void initState() {
    super.initState();
    _carregarListasDinamicas();

    if (widget.dadosAtuais != null) {
      _nomeOperacao = widget.dadosAtuais!['nome'] ?? '';
      _setorSelecionadoId = widget.dadosAtuais!['setorId'];
      _setorSelecionadoNome = widget.dadosAtuais!['setorNome'];
      _maquinaSelecionadaId = widget.dadosAtuais!['maquinaId'];
      _maquinaSelecionadaNome = widget.dadosAtuais!['maquinaNome'];
      _tipo = widget.dadosAtuais!['tipo'] ?? 'Interno';

      _custoExterno = (widget.dadosAtuais!['custoExterno'] ?? 0).toDouble();
      _unidadeExternaId = widget.dadosAtuais!['unidadeExternaId'];
      _unidadeExternaNome = widget.dadosAtuais!['unidadeExternaNome'];

      // ENGENHARIA REVERSA DO TEMPO CENTESIMAL PARA MINUTOS/SEGUNDOS
      double tempoDecimal = (widget.dadosAtuais!['tempoMinutos'] ?? 0)
          .toDouble();
      if (tempoDecimal > 0) {
        int m = tempoDecimal.floor();
        int s = ((tempoDecimal - m) * 60).round();
        _minutosCtrl.text = m > 0 ? m.toString() : '';
        _segundosCtrl.text = s > 0 ? s.toString() : '';
      }

      _imagemBase64 = widget.dadosAtuais!['imagemBase64'];
      _videoUrlFirebase = widget.dadosAtuais!['videoUrl'];

      if (_videoUrlFirebase != null && _videoUrlFirebase!.isNotEmpty) {
        _inicializarPlayerVideo(url: _videoUrlFirebase);
      }
    }
  }

  @override
  void dispose() {
    _minutosCtrl.dispose();
    _segundosCtrl.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // --- CÁLCULO DINÂMICO PARA MOSTRAR NA TELA ---
  double _calcularTempoDecimal() {
    int m = int.tryParse(_minutosCtrl.text) ?? 0;
    int s = int.tryParse(_segundosCtrl.text) ?? 0;
    return m + (s / 60.0);
  }

  Future<void> _carregarListasDinamicas() async {
    try {
      final setoresSnap = await FirebaseFirestore.instance
          .collection('setores_industria')
          .orderBy('nome')
          .get();
      final maquinasSnap = await FirebaseFirestore.instance
          .collection('maquinas_industria')
          .orderBy('nome')
          .get();
      final unidadesSnap = await FirebaseFirestore.instance
          .collection('unidades_medida')
          .get();

      setState(() {
        _listaSetores = setoresSnap.docs
            .map((d) => {'id': d.id, 'nome': d['nome']})
            .toList();
        _listaMaquinas = maquinasSnap.docs
            .map((d) => {'id': d.id, 'nome': d['nome']})
            .toList();
        _listaUnidades = unidadesSnap.docs
            .map((d) => {'id': d.id, 'nome': d['sigla'] ?? d['nome']})
            .toList();
      });
    } catch (e) {
      debugPrint("Erro ao carregar listas dinâmicas: $e");
    }
  }

  Future<void> _capturarImagem(ImageSource fonte) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: fonte,
        imageQuality: 50,
        maxWidth: 800,
      );
      if (foto != null) {
        final bytes = await foto.readAsBytes();
        setState(() {
          _imagemBase64 = base64Encode(bytes);
          _videoLocalFile = null;
          _videoController?.dispose();
          _videoController = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _capturarVideo(ImageSource fonte) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: fonte,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null) {
        setState(() {
          _videoLocalFile = File(video.path);
          _imagemBase64 = null;
          _videoUrlFirebase = null;
        });
        _inicializarPlayerVideo(arquivoLocal: _videoLocalFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao capturar vídeo: $e')));
    }
  }

  void _inicializarPlayerVideo({String? url, File? arquivoLocal}) {
    if (url != null) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    } else if (arquivoLocal != null) {
      _videoController = VideoPlayerController.file(arquivoLocal);
    } else {
      return;
    }

    _videoController!.initialize().then((_) {
      setState(() {});
    });
  }

  Future<void> _salvarProcesso() async {
    if (!_formKey.currentState!.validate()) return;
    if (_setorSelecionadoId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione um Setor!')));
      return;
    }
    if (_tipo == 'Externo' && _unidadeExternaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione a Unidade de Cobrança do serviço externo!'),
        ),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _statusCarregamento = 'Salvando dados...';
    });

    String? linkVideoFinal = _videoUrlFirebase;

    try {
      if (_videoLocalFile != null) {
        setState(
          () => _statusCarregamento = 'Enviando vídeo para a nuvem... Aguarde.',
        );
        final String nomeArquivo =
            '${DateTime.now().millisecondsSinceEpoch}.mp4';
        final Reference pastaStorage = FirebaseStorage.instance.ref().child(
          'clientes/teste_textil/treinamentos_operacao/$nomeArquivo',
        );
        final UploadTask uploadTask = pastaStorage.putFile(_videoLocalFile!);
        final TaskSnapshot snapshot = await uploadTask;
        linkVideoFinal = await snapshot.ref.getDownloadURL();
      }

      setState(() => _statusCarregamento = 'Finalizando cadastro...');

      final dados = {
        'nome': _nomeOperacao,
        'setorId': _setorSelecionadoId,
        'setorNome': _setorSelecionadoNome,
        'maquinaId': _maquinaSelecionadaId,
        'maquinaNome': _maquinaSelecionadaNome,
        'tipo': _tipo,

        // CONVERSÃO FINAL PARA SALVAR NO BANCO
        'tempoMinutos': _tipo == 'Interno' ? _calcularTempoDecimal() : 0.0,

        'custoExterno': _tipo == 'Externo' ? _custoExterno : 0.0,
        'unidadeExternaId': _tipo == 'Externo' ? _unidadeExternaId : null,
        'unidadeExternaNome': _tipo == 'Externo' ? _unidadeExternaNome : null,
        'imagemBase64': _imagemBase64,
        'videoUrl': linkVideoFinal,
        'dataRegistro': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      };

      if (widget.processoId == null) {
        dados['criadoEm'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('processos_engenharia')
            .add(dados);
      } else {
        await FirebaseFirestore.instance
            .collection('processos_engenharia')
            .doc(widget.processoId)
            .update(dados);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operação salva com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      setState(() {
        _isLoading = false;
        _statusCarregamento = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.processoId == null ? 'Nova Operação' : 'Editar Operação',
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.teal),
                  const SizedBox(height: 16),
                  Text(
                    _statusCarregamento,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value:
                                _listaSetores.any(
                                  (s) => s['id'] == _setorSelecionadoId,
                                )
                                ? _setorSelecionadoId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Setor de Produção',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.domain),
                            ),
                            items: _listaSetores
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s['id'],
                                    child: Text(s['nome']),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() {
                              _setorSelecionadoId = v;
                              _setorSelecionadoNome = _listaSetores.firstWhere(
                                (s) => s['id'] == v,
                              )['nome'];
                            }),
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
                            onPressed: () => _modalNovoCadastro(
                              'setores_industria',
                              'Novo Setor',
                              'Ex: Tecelagem',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      initialValue: _nomeOperacao,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Operação',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.precision_manufacturing),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Informe a operação' : null,
                      onSaved: (v) => _nomeOperacao = v!,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value:
                                _listaMaquinas.any(
                                  (m) => m['id'] == _maquinaSelecionadaId,
                                )
                                ? _maquinaSelecionadaId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Máquina / Tipo de Costura',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.settings),
                            ),
                            items: _listaMaquinas
                                .map(
                                  (m) => DropdownMenuItem<String>(
                                    value: m['id'],
                                    child: Text(m['nome']),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() {
                              _maquinaSelecionadaId = v;
                              _maquinaSelecionadaNome = _listaMaquinas
                                  .firstWhere((m) => m['id'] == v)['nome'];
                            }),
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
                            onPressed: () => _modalNovoCadastro(
                              'maquinas_industria',
                              'Nova Máquina',
                              'Ex: Overlock 7mm',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Execução',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sync_alt),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Interno',
                          child: Text('Fábrica (Interno)'),
                        ),
                        DropdownMenuItem(
                          value: 'Externo',
                          child: Text('Facção / Serviço (Externo)'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _tipo = v!),
                    ),
                    const SizedBox(height: 16),

                    // --- BLOCO DE CUSTOS INTELIGENTE ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tipo == 'Interno'
                                ? 'Tempo Padrão Cronometrado'
                                : 'Parâmetros de Custeio Externo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_tipo == 'Interno') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _minutosCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Minutos',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.timer),
                                      fillColor: Colors.white,
                                      filled: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(
                                      () {},
                                    ), // Atualiza a label em tempo real
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _segundosCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Segundos',
                                      border: OutlineInputBorder(),
                                      fillColor: Colors.white,
                                      filled: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Custo calculado sobre: ${_calcularTempoDecimal().toStringAsFixed(2)} minutos centesimais.',
                              style: TextStyle(
                                color: Colors.teal.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: _custoExterno > 0
                                        ? _custoExterno.toString()
                                        : '',
                                    decoration: const InputDecoration(
                                      labelText: 'Valor Cobrado (R\$)',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.attach_money),
                                      fillColor: Colors.white,
                                      filled: true,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onSaved: (v) => _custoExterno =
                                        double.tryParse(
                                          v?.replaceAll(',', '.') ?? '0',
                                        ) ??
                                        0.0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    value:
                                        _listaUnidades.any(
                                          (u) => u['id'] == _unidadeExternaId,
                                        )
                                        ? _unidadeExternaId
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Por Unidade',
                                      border: OutlineInputBorder(),
                                      fillColor: Colors.white,
                                      filled: true,
                                    ),
                                    items: _listaUnidades
                                        .map(
                                          (u) => DropdownMenuItem<String>(
                                            value: u['id'],
                                            child: Text(
                                              u['nome']
                                                  .toString()
                                                  .toUpperCase(),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                      _unidadeExternaId = v;
                                      _unidadeExternaNome = _listaUnidades
                                          .firstWhere(
                                            (u) => u['id'] == v,
                                          )['nome'];
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- MOTOR VISUAL ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mídia de Treinamento e Padrão',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            'Grave um vídeo de até 30s mostrando a operação.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 16),

                          if (_videoController != null &&
                              _videoController!.value.isInitialized) ...[
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: AspectRatio(
                                aspectRatio:
                                    _videoController!.value.aspectRatio,
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    VideoPlayer(_videoController!),
                                    _ControlesPlayer(
                                      controller: _videoController!,
                                    ),
                                    Positioned(
                                      top: 5,
                                      right: 5,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.red,
                                        radius: 15,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          onPressed: () => setState(() {
                                            _videoLocalFile = null;
                                            _videoUrlFirebase = null;
                                            _videoController?.dispose();
                                            _videoController = null;
                                          }),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else if (_imagemBase64 != null) ...[
                            Center(
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      base64Decode(_imagemBase64!),
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.red,
                                      radius: 15,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        onPressed: () => setState(
                                          () => _imagemBase64 = null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo.shade100,
                                  foregroundColor: Colors.indigo.shade900,
                                ),
                                icon: const Icon(Icons.videocam),
                                label: const Text('Gravar Vídeo'),
                                onPressed: () =>
                                    _capturarVideo(ImageSource.camera),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade100,
                                  foregroundColor: Colors.teal.shade900,
                                ),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Tirar Foto'),
                                onPressed: () =>
                                    _capturarImagem(ImageSource.camera),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text(
                        'SALVAR OPERAÇÃO',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _salvarProcesso,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _modalNovoCadastro(String colecao, String titulo, String hint) {
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
                  await FirebaseFirestore.instance
                      .collection(colecao)
                      .add(dadosCadastro);
                  Navigator.pop(context);
                  _carregarListasDinamicas();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$titulo criado!')));
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

class _ControlesPlayer extends StatelessWidget {
  final VideoPlayerController controller;
  const _ControlesPlayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: controller.value.isPlaying
              ? const SizedBox.shrink()
              : Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 50.0,
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
          },
        ),
      ],
    );
  }
}
