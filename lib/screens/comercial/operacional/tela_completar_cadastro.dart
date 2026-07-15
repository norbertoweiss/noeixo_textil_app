import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

// Importando o nosso novo bloco de lego!
import '../../../widgets/forms/bloco_locais_entrega.dart';

class TelaCompletarCadastro extends StatefulWidget {
  final String clienteId;
  final Map<String, dynamic> dadosIniciais;

  const TelaCompletarCadastro({
    super.key,
    required this.clienteId,
    required this.dadosIniciais,
  });

  @override
  State<TelaCompletarCadastro> createState() => _TelaCompletarCadastroState();
}

class _TelaCompletarCadastroState extends State<TelaCompletarCadastro> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _ieCtrl = TextEditingController();

  // Variáveis de estado que o Bloco de Entrega vai controlar
  bool _isMesmoEndereco = true;
  List<Map<String, dynamic>> _locaisEntrega = [];

  String? _fotoFachadaBase64;
  double? _latAtual;
  double? _lngAtual;
  bool _gpsCapturado = false;

  @override
  void initState() {
    super.initState();
    _ieCtrl.text = widget.dadosIniciais['inscricao_estadual'] ?? '';
    _isMesmoEndereco = widget.dadosIniciais['entrega_mesmo_fiscal'] ?? true;
    if (widget.dadosIniciais['locais_entrega'] != null) {
      _locaisEntrega = List<Map<String, dynamic>>.from(
        widget.dadosIniciais['locais_entrega'],
      );
    }
  }

  Future<void> _capturarGPS() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Ative o GPS do seu aparelho.');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception('Permissão de GPS negada.');
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latAtual = position.latitude;
        _lngAtual = position.longitude;
        _gpsCapturado = true;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro GPS: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _capturarFachada() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 40,
    );
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() => _fotoFachadaBase64 = base64Encode(bytes));
    }
  }

  Future<void> _enviarParaAnalise() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      String statusAtual =
          widget.dadosIniciais['status_credito'] ?? 'Em Análise';
      if (statusAtual == 'Pendente Enriquecimento')
        statusAtual = 'Pendente Cadastro';

      Map<String, dynamic> dadosFinais = {
        'is_rascunho': false,
        'status_credito': statusAtual,
        'inscricao_estadual': _ieCtrl.text,
        'latitude_entrega':
            _latAtual ?? widget.dadosIniciais['latitude_entrega'],
        'longitude_entrega':
            _lngAtual ?? widget.dadosIniciais['longitude_entrega'],
        'foto_fachada_base64':
            _fotoFachadaBase64 ?? widget.dadosIniciais['foto_fachada_base64'],
        'entrega_mesmo_fiscal': _isMesmoEndereco,
      };

      if (!_isMesmoEndereco) dadosFinais['locais_entrega'] = _locaisEntrega;

      try {
        await FirebaseFirestore.instance
            .collection('clientes')
            .doc(widget.clienteId)
            .update(dadosFinais);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cadastro completado com sucesso!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCepGeral = widget.dadosIniciais['cep_fiscal'].toString().endsWith(
      '000',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Modo Carro: Completar Cadastro')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.dadosIniciais['razao_social'] ??
                          'Cliente sem nome',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 32),

                    if (isCepGeral)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'O CEP validado é Geral (termina em 000). O Roteirizador vai falhar. Use o GPS obrigatoriamente!',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Text(
                      '1. Auditoria de Campo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _gpsCapturado
                                  ? Colors.green
                                  : Colors.white,
                              foregroundColor: _gpsCapturado
                                  ? Colors.white
                                  : Colors.indigo,
                              side: BorderSide(
                                color: _gpsCapturado
                                    ? Colors.green
                                    : Colors.indigo,
                              ),
                            ),
                            icon: Icon(
                              _gpsCapturado ? Icons.check : Icons.gps_fixed,
                            ),
                            label: Text(
                              _gpsCapturado ? 'GPS Salvo' : 'GPS Atual',
                            ),
                            onPressed: _capturarGPS,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _fotoFachadaBase64 != null
                                  ? Colors.green
                                  : Colors.white,
                              foregroundColor: _fotoFachadaBase64 != null
                                  ? Colors.white
                                  : Colors.indigo,
                              side: BorderSide(
                                color: _fotoFachadaBase64 != null
                                    ? Colors.green
                                    : Colors.indigo,
                              ),
                            ),
                            icon: Icon(
                              _fotoFachadaBase64 != null
                                  ? Icons.image
                                  : Icons.camera_alt,
                            ),
                            label: Text(
                              _fotoFachadaBase64 != null
                                  ? 'Foto Salva'
                                  : 'Fachada/Doca',
                            ),
                            onPressed: _capturarFachada,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ===============================================================
                    // NOSSO NOVO WIDGET ISOLADO FAZENDO O TRABALHO PESADO
                    // ===============================================================
                    BlocoLocaisEntrega(
                      isMesmoEndereco: _isMesmoEndereco,
                      ruaFiscal: widget.dadosIniciais['rua_fiscal'] ?? '',
                      locaisEntrega: _locaisEntrega,
                      onChangedMesmoEndereco: (val) =>
                          setState(() => _isMesmoEndereco = val),
                      onUpdateLocais: (novaLista) =>
                          setState(() => _locaisEntrega = novaLista),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      '3. Dados Fiscais Pendentes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ieCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Inscrição Estadual (Ou digite ISENTO)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text(
                        'CONCLUIR CADASTRO DO CLIENTE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _enviarParaAnalise,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
