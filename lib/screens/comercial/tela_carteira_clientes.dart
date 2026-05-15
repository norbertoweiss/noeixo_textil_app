import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class TelaCarteiraClientes extends StatefulWidget {
  const TelaCarteiraClientes({super.key});

  @override
  State<TelaCarteiraClientes> createState() => _TelaCarteiraClientesState();
}

class _TelaCarteiraClientesState extends State<TelaCarteiraClientes> {
  final String _idRepresentanteLogado = "REP_001"; // Simulação de Login

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Carteira de Clientes & CRM'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.location_on), text: 'Minha Rota'),
              Tab(icon: Icon(Icons.bolt), text: 'Novo Prospecto (Balcão)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AbaListaClientes(representanteId: _idRepresentanteLogado),
            _AbaNovoClienteBalcao(representanteId: _idRepresentanteLogado),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 1: MINHA ROTA (COM PESQUISA E FILTROS)
// ============================================================================
class _AbaListaClientes extends StatefulWidget {
  final String representanteId;
  const _AbaListaClientes({required this.representanteId});

  @override
  State<_AbaListaClientes> createState() => _AbaListaClientesState();
}

class _AbaListaClientesState extends State<_AbaListaClientes> {
  String _filtroStatus = 'Todos';
  String _termoBusca = '';
  final TextEditingController _buscaCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // BARRA DE PESQUISA E FILTROS
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _buscaCtrl,
                    decoration: InputDecoration(
                      labelText: 'Buscar Cliente (Razão/Fantasia)',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => _termoBusca = val.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _filtroStatus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'Aprovado',
                        child: Text('Aprovados'),
                      ),
                      DropdownMenuItem(
                        value: 'Em Análise',
                        child: Text('Em Análise'),
                      ),
                      DropdownMenuItem(
                        value: 'Bloqueado',
                        child: Text('Bloqueados'),
                      ),
                      DropdownMenuItem(
                        value: 'Rascunho',
                        child: Text('Rascunhos'),
                      ),
                    ],
                    onChanged: (val) => setState(() => _filtroStatus = val!),
                  ),
                ),
              ],
            ),
          ),

          // LISTA DE CLIENTES
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clientes')
                  .where('representante_id', isEqualTo: widget.representanteId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Erro ao buscar dados no Firebase:\n${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum cliente na sua rota.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // APLICAÇÃO DOS FILTROS LOCAIS E ORDENAÇÃO NA MEMÓRIA
                var docsFiltrados = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String razao = (data['razao_social'] ?? '')
                      .toString()
                      .toLowerCase();
                  String fantasia = (data['nome_fantasia'] ?? '')
                      .toString()
                      .toLowerCase();
                  String statusCredito = data['status_credito'] ?? 'Em Análise';
                  bool isRascunho = data['is_rascunho'] ?? false;

                  bool matchBusca =
                      razao.contains(_termoBusca) ||
                      fantasia.contains(_termoBusca);
                  if (!matchBusca) return false;

                  if (_filtroStatus == 'Rascunho' && !isRascunho) return false;
                  if (_filtroStatus != 'Todos' && _filtroStatus != 'Rascunho') {
                    if (isRascunho || statusCredito != _filtroStatus)
                      return false;
                  }

                  return true;
                }).toList();

                docsFiltrados.sort((a, b) {
                  String nomeA =
                      ((a.data() as Map<String, dynamic>)['razao_social'] ?? '')
                          .toString()
                          .toLowerCase();
                  String nomeB =
                      ((b.data() as Map<String, dynamic>)['razao_social'] ?? '')
                          .toString()
                          .toLowerCase();
                  return nomeA.compareTo(nomeB);
                });

                if (docsFiltrados.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum cliente atende a este filtro.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docsFiltrados.length,
                  padding: const EdgeInsets.only(bottom: 80, top: 8),
                  itemBuilder: (context, index) {
                    var doc = docsFiltrados[index];
                    var data = doc.data() as Map<String, dynamic>;

                    String statusCredito =
                        data['status_credito'] ?? 'Em Análise';
                    bool isRascunho = data['is_rascunho'] ?? false;

                    if (isRascunho) {
                      return Card(
                        color: Colors.orange.shade50,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(
                              Icons.edit_document,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            data['razao_social'] ?? 'Sem Razão Social',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            '⚠️ Rascunho Incompleto.\nFalta endereço logístico e GPS.',
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 12,
                            ),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TelaEnriquecimentoCarro(
                                  clienteId: doc.id,
                                  dadosIniciais: data,
                                ),
                              ),
                            ),
                            child: const Text('Completar'),
                          ),
                        ),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusCredito == 'Aprovado'
                              ? Colors.green[100]
                              : (statusCredito == 'Bloqueado'
                                    ? Colors.red[100]
                                    : Colors.blue[100]),
                          child: Icon(
                            statusCredito == 'Aprovado'
                                ? Icons.store
                                : (statusCredito == 'Bloqueado'
                                      ? Icons.block
                                      : Icons.hourglass_empty),
                            color: statusCredito == 'Aprovado'
                                ? Colors.green
                                : (statusCredito == 'Bloqueado'
                                      ? Colors.red
                                      : Colors.blue),
                          ),
                        ),
                        title: Text(
                          data['razao_social'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${data['cidade_fiscal']} - ${data['bairro_fiscal']}\nCrédito: $statusCredito',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'pedido') {
                              if (statusCredito != 'Aprovado') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Cliente sem crédito aprovado para pedidos.',
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Abrir carrinho (Em Breve)'),
                                  ),
                                );
                              }
                            }
                            if (val == 'crm')
                              _modalCRM(context, doc.id, data['razao_social']);
                            if (val == 'editar') {
                              // O botão Editar também abre o Modo Carro, pois lá estão todos os dados do cliente
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TelaEnriquecimentoCarro(
                                    clienteId: doc.id,
                                    dadosIniciais: data,
                                  ),
                                ),
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'pedido',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shopping_cart,
                                    color: Colors.indigo,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Novo Pedido'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'crm',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.record_voice_over,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Registrar Visita'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'editar',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: Colors.blueGrey,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Editar Ficha Completa'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _modalCRM(BuildContext context, String clienteId, String nome) {
    String tipo = 'Visita Frustrada';
    TextEditingController obs = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(
            'CRM: $nome',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: tipo,
                decoration: const InputDecoration(
                  labelText: 'Resultado da Visita',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Visita Frustrada',
                    child: Text('❌ Visita Frustrada (Ausente)'),
                  ),
                  DropdownMenuItem(
                    value: 'Visita Efetuada',
                    child: Text('✅ Visita de Relacionamento'),
                  ),
                  DropdownMenuItem(
                    value: 'Ligação / WhatsApp',
                    child: Text('📱 Contato Digital'),
                  ),
                ],
                onChanged: (v) => setModalState(() => tipo = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: obs,
                decoration: const InputDecoration(
                  labelText: 'Observações (Motivo, Próximo passo)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('clientes')
                    .doc(clienteId)
                    .collection('historico_crm')
                    .add({
                      'dataRegistro': FieldValue.serverTimestamp(),
                      'tipo': tipo,
                      'observacao': obs.text,
                      'representante': widget.representanteId,
                    });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ação gravada no CRM!')),
                  );
                }
              },
              child: const Text('Gravar no Histórico'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 2: NOVO PROSPECTO - MODO BALCÃO (RÁPIDO)
// ============================================================================
class _AbaNovoClienteBalcao extends StatefulWidget {
  final String representanteId;
  const _AbaNovoClienteBalcao({required this.representanteId});

  @override
  State<_AbaNovoClienteBalcao> createState() => _AbaNovoClienteBalcaoState();
}

class _AbaNovoClienteBalcaoState extends State<_AbaNovoClienteBalcao> {
  final _formKey = GlobalKey<FormState>();
  bool _buscandoCNPJ = false;
  bool _cnpjValidado = false;
  bool _salvando = false;

  Map<String, dynamic> _dadosReceita = {};

  final _cnpjCtrl = TextEditingController();
  final _redeCtrl = TextEditingController();
  final _compradorCtrl = TextEditingController();
  final _whatsCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  Future<void> _buscarCNPJ() async {
    String cnpjLimpo = _cnpjCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cnpjLimpo.length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O CNPJ deve conter 14 números.')),
      );
      return;
    }

    setState(() {
      _buscandoCNPJ = true;
      _cnpjValidado = false;
    });

    try {
      final response = await http.get(
        Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$cnpjLimpo'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['descricao_situacao_cadastral'] != 'ATIVA') {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'ALERTA: Empresa ${data['descricao_situacao_cadastral']}',
                ),
                backgroundColor: Colors.red,
              ),
            );
        }

        setState(() {
          _dadosReceita = data;
          _cnpjValidado = true;
        });
      } else {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('CNPJ não encontrado.')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      setState(() => _buscandoCNPJ = false);
    }
  }

  Future<void> _salvarRascunho() async {
    if (_formKey.currentState!.validate() && _cnpjValidado) {
      setState(() => _salvando = true);
      try {
        await FirebaseFirestore.instance.collection('clientes').add({
          'is_rascunho': true,
          'representante_id': widget.representanteId,
          'status_credito': 'Pendente Enriquecimento',
          'data_criacao_rascunho': FieldValue.serverTimestamp(),

          'cnpj': _cnpjCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
          'razao_social': _dadosReceita['razao_social'] ?? '',
          'nome_fantasia': _dadosReceita['nome_fantasia'] ?? '',
          'cep_fiscal': _dadosReceita['cep'] ?? '',
          'rua_fiscal': _dadosReceita['logradouro'] ?? '',
          'num_fiscal': _dadosReceita['numero'] ?? '',
          'bairro_fiscal': _dadosReceita['bairro'] ?? '',
          'cidade_fiscal': _dadosReceita['municipio'] ?? '',
          'uf_fiscal': _dadosReceita['uf'] ?? '',

          'grupo_economico': _redeCtrl.text,
          'contato_comprador': _compradorCtrl.text,
          'whatsapp': _whatsCtrl.text,
          'email_nfe': _emailCtrl.text,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rascunho Salvo! Conclua depois no Modo Carro.'),
            ),
          );
          _limparFormulario();
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      } finally {
        if (mounted) setState(() => _salvando = false);
      }
    }
  }

  void _limparFormulario() {
    _cnpjCtrl.clear();
    _redeCtrl.clear();
    _compradorCtrl.clear();
    _whatsCtrl.clear();
    _emailCtrl.clear();
    setState(() {
      _cnpjValidado = false;
      _dadosReceita = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '⚡ Modo Balcão: Capture apenas o essencial frente ao cliente.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _cnpjCtrl,
              decoration: InputDecoration(
                labelText: 'CNPJ (Somente Números)',
                border: const OutlineInputBorder(),
                suffixIcon: _buscandoCNPJ
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search, color: Colors.indigo),
                        onPressed: _buscarCNPJ,
                      ),
              ),
              keyboardType: TextInputType.number,
            ),

            if (_cnpjValidado) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Empresa Validada',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_dadosReceita['razao_social']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_dadosReceita['logradouro']}, ${_dadosReceita['numero']} - ${_dadosReceita['municipio']}/${_dadosReceita['uf']}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _compradorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do Comprador',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _whatsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'E-mail do Cliente',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _redeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pertence a qual Rede / Grupo? (Opcional)',
                  hintText: 'Ex: Lojas Silva',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 32),
              _salvando
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'SALVAR COMO RASCUNHO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _salvarRascunho,
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MODO CARRO (TELA COMPLETA DE ENRIQUECIMENTO E LOGÍSTICA)
// ============================================================================
class TelaEnriquecimentoCarro extends StatefulWidget {
  final String clienteId;
  final Map<String, dynamic> dadosIniciais;

  const TelaEnriquecimentoCarro({
    super.key,
    required this.clienteId,
    required this.dadosIniciais,
  });

  @override
  State<TelaEnriquecimentoCarro> createState() =>
      _TelaEnriquecimentoCarroState();
}

class _TelaEnriquecimentoCarroState extends State<TelaEnriquecimentoCarro> {
  final _formKey = GlobalKey<FormState>();
  bool _isMesmoEndereco = true;
  bool _isLoading = false;

  final _ieCtrl = TextEditingController();

  // ARQUITETURA DINÂMICA: Lista de Locais de Entrega
  List<Map<String, dynamic>> _locaisEntrega = [];

  String? _fotoFachadaBase64;
  double? _latAtual;
  double? _lngAtual;
  bool _gpsCapturado = false;

  @override
  void initState() {
    super.initState();
    _ieCtrl.text = widget.dadosIniciais['inscricao_estadual'] ?? '';

    // VERIFICA SE JÁ EXISTEM DADOS LOGÍSTICOS E CARREGA
    _isMesmoEndereco = widget.dadosIniciais['entrega_mesmo_fiscal'] ?? true;
    if (widget.dadosIniciais['locais_entrega'] != null) {
      _locaisEntrega = List<Map<String, dynamic>>.from(
        widget.dadosIniciais['locais_entrega'],
      );
    }
  }

  // MOTOR DE GPS REAL (GEOLOCATOR)
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

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permissões de GPS bloqueadas permanentemente.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latAtual = position.latitude;
        _lngAtual = position.longitude;
        _gpsCapturado = true;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coordenadas exatas salvas!')),
        );
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

  // MODAL DINÂMICO PARA ADICIONAR OU EDITAR LOCAL DE ENTREGA
  void _modalEntrega({int? indexEdicao}) {
    final cepCtrl = TextEditingController();
    final ufCtrl = TextEditingController();
    final ruaCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    final compCtrl = TextEditingController();
    final bairroCtrl = TextEditingController();
    final cidadeCtrl = TextEditingController();
    final instrucaoCtrl = TextEditingController();

    if (indexEdicao != null) {
      final item = _locaisEntrega[indexEdicao];
      cepCtrl.text = item['cep'] ?? '';
      ufCtrl.text = item['uf'] ?? '';
      ruaCtrl.text = item['rua'] ?? '';
      numCtrl.text = item['numero'] ?? '';
      compCtrl.text = item['complemento'] ?? '';
      bairroCtrl.text = item['bairro'] ?? '';
      cidadeCtrl.text = item['cidade'] ?? '';
      instrucaoCtrl.text = item['instrucao'] ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          indexEdicao == null ? 'Adicionar Local de Entrega' : 'Editar Local',
          style: const TextStyle(fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: cepCtrl,
                      decoration: const InputDecoration(
                        labelText: 'CEP',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: ufCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Estado (UF)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: ruaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Rua / Logradouro',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: numCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nº',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: compCtrl,
                decoration: const InputDecoration(
                  labelText: 'Complemento (Doca, Loja 2)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: bairroCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bairro',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: cidadeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cidade',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instrucaoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instruções ao Motorista',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
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
              final novoLocal = {
                'cep': cepCtrl.text,
                'uf': ufCtrl.text,
                'rua': ruaCtrl.text,
                'numero': numCtrl.text,
                'complemento': compCtrl.text,
                'bairro': bairroCtrl.text,
                'cidade': cidadeCtrl.text,
                'instrucao': instrucaoCtrl.text,
                'ativo': indexEdicao == null
                    ? true
                    : (_locaisEntrega[indexEdicao]['ativo'] ?? true),
              };

              setState(() {
                if (indexEdicao == null) {
                  _locaisEntrega.add(novoLocal);
                } else {
                  _locaisEntrega[indexEdicao] = novoLocal;
                }
              });
              Navigator.pop(context);
            },
            child: Text(
              indexEdicao == null ? 'Adicionar à Lista' : 'Salvar Alterações',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarParaAnalise() async {
    if (_formKey.currentState!.validate()) {
      if (!_isMesmoEndereco && _locaisEntrega.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adicione pelo menos um local de entrega na lista!'),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      Map<String, dynamic> dadosFinais = {
        'is_rascunho': false,
        'status_credito':
            widget.dadosIniciais['status_credito'] ?? 'Em Análise',
        'inscricao_estadual': _ieCtrl.text,
        'latitude_entrega':
            _latAtual ?? widget.dadosIniciais['latitude_entrega'],
        'longitude_entrega':
            _lngAtual ?? widget.dadosIniciais['longitude_entrega'],
        'foto_fachada_base64':
            _fotoFachadaBase64 ?? widget.dadosIniciais['foto_fachada_base64'],
        'entrega_mesmo_fiscal': _isMesmoEndereco,
      };

      if (!_isMesmoEndereco) {
        dadosFinais['locais_entrega'] = _locaisEntrega;
      }

      try {
        await FirebaseFirestore.instance
            .collection('clientes')
            .doc(widget.clienteId)
            .update(dadosFinais);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ficha do cliente guardada com sucesso!'),
            ),
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
      appBar: AppBar(title: const Text('Modo Carro: Enriquecimento')),
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
                      widget.dadosIniciais['razao_social'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'CNPJ: ${widget.dadosIniciais['cnpj']} | Rede: ${widget.dadosIniciais['grupo_economico'] ?? 'Nenhuma'}',
                      style: const TextStyle(color: Colors.grey),
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

                    const Text(
                      '2. Gestor de Filiais e Docas',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.teal,
                      ),
                    ),
                    Card(
                      elevation: 0,
                      color: Colors.teal.shade50,
                      child: SwitchListTile(
                        title: const Text(
                          'A Entrega é no mesmo endereço da Nota Fiscal?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          widget.dadosIniciais['rua_fiscal'],
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: _isMesmoEndereco,
                        activeColor: Colors.teal,
                        onChanged: (val) =>
                            setState(() => _isMesmoEndereco = val),
                      ),
                    ),

                    // ÁREA DINÂMICA DE MÚLTIPLOS LOCAIS DE ENTREGA
                    if (!_isMesmoEndereco) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Locais de Entrega Cadastrados:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_locaisEntrega.isEmpty)
                        const Text(
                          'Nenhum local adicionado. Clique no botão abaixo.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                      ..._locaisEntrega.asMap().entries.map((entry) {
                        int idx = entry.key;
                        Map<String, dynamic> local = entry.value;
                        bool isAtivo = local['ativo'] ?? true;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isAtivo ? Colors.white : Colors.grey.shade200,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAtivo
                                  ? Colors.teal
                                  : Colors.grey,
                              child: Icon(
                                Icons.local_shipping,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              '${local['rua']}, ${local['numero']} - ${local['cidade']}',
                              style: TextStyle(
                                decoration: isAtivo
                                    ? TextDecoration.none
                                    : TextDecoration.lineThrough,
                                color: isAtivo ? Colors.black : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              'Comp: ${local['complemento']} | Ref: ${local['instrucao']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: isAtivo,
                                  activeColor: Colors.teal,
                                  onChanged: (val) {
                                    setState(
                                      () => _locaisEntrega[idx]['ativo'] = val,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blueGrey,
                                  ),
                                  onPressed: () =>
                                      _modalEntrega(indexEdicao: idx),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Adicionar Novo Local de Entrega',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _modalEntrega(),
                      ),
                    ],
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
                        'GUARDAR FICHA DO CLIENTE',
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
