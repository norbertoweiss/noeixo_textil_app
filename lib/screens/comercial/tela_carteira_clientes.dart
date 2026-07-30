import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ============================================================================
// IMPORTANDO OS BLOCOS DE LEGO E SERVIÇOS
// ============================================================================
import '../../widgets/cards/card_cliente_rota.dart';
import '../../widgets/smart/barra_filtros_comercial.dart';
import '../../widgets/smart/filtro_geografico.dart';
import '../../services/motor_geografico.dart';

class TelaCarteiraClientes extends StatefulWidget {
  final String empresaId;
  const TelaCarteiraClientes({super.key, required this.empresaId});

  @override
  State<TelaCarteiraClientes> createState() => _TelaCarteiraClientesState();
}

class _TelaCarteiraClientesState extends State<TelaCarteiraClientes> {
  String? _idRepresentanteLogado;
  bool _isMaster = false;
  bool _carregandoPerfil = true;
  List<String> _cidadesAtuacao = [];

  @override
  void initState() {
    super.initState();
    _identificarVendedorLogado();
  }

  Future<void> _identificarVendedorLogado() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.email != null) {
        final snap = await FirebaseFirestore.instance
            .collection('vendedores')
            .where('empresa_id', isEqualTo: widget.empresaId)
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          final doc = snap.docs.first;
          final dados = doc.data();

          bool isMaster = dados['atendimento_global'] ?? false;
          List<String> cidadesDaRota = [];

          if (!isMaster) {
            List<dynamic> regioesDoVendedor = dados['regioes_vinculadas'] ?? [];
            cidadesDaRota = await MotorGeografico.obterCidadesDaRota(
              regioesDoVendedor,
            );
          }

          setState(() {
            _idRepresentanteLogado = doc.id;
            _isMaster = isMaster;
            _cidadesAtuacao = cidadesDaRota;
            _carregandoPerfil = false;
          });
          return;
        }
      }

      setState(() {
        _idRepresentanteLogado = 'TESTE_LOCAL';
        _isMaster = true;
        _carregandoPerfil = false;
      });
    } catch (e) {
      debugPrint('Erro ao identificar vendedor: $e');
      setState(() => _carregandoPerfil = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoPerfil) {
      return const Scaffold(
        backgroundColor: Colors.indigo,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Autenticando credenciais da rua...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Carteira de Clientes & CRM',
                style: TextStyle(fontSize: 18),
              ),
              if (_isMaster)
                const Text(
                  '👑 Visão de Gestão Master (Acesso Global)',
                  style: TextStyle(fontSize: 12, color: Colors.amberAccent),
                ),
            ],
          ),
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
            _AbaListaClientes(
              representanteId: _idRepresentanteLogado ?? 'DESCONHECIDO',
              empresaId: widget.empresaId,
              isMaster: _isMaster,
              cidadesAtuacao: _cidadesAtuacao,
            ),
            _AbaNovoClienteBalcao(
              representanteId: _idRepresentanteLogado ?? 'DESCONHECIDO',
              empresaId: widget.empresaId,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 1: MINHA ROTA (COM SUPERPODERES PARA O MASTER)
// ============================================================================
class _AbaListaClientes extends StatefulWidget {
  final String representanteId;
  final String empresaId;
  final bool isMaster;
  final List<String> cidadesAtuacao;

  const _AbaListaClientes({
    required this.representanteId,
    required this.empresaId,
    required this.isMaster,
    required this.cidadesAtuacao,
  });

  @override
  State<_AbaListaClientes> createState() => _AbaListaClientesState();
}

class _AbaListaClientesState extends State<_AbaListaClientes> {
  String _filtroStatus = 'Todos';
  String _filtroAtivo = 'Ativos';
  String _termoBusca = '';
  List<String> _filtroRepresentantes = [];

  String _filtroUf = 'Todas';
  List<String> _filtrosCidades = [];

  // Variáveis exclusivas do Vendedor Master
  List<Map<String, dynamic>> _listaRegioesMaster = [];
  String? _filtroRegiaoSelecionada;
  List<String> _cidadesDaRegiaoSelecionada = [];

  @override
  void initState() {
    super.initState();
    if (widget.isMaster) {
      _carregarRegioesParaMaster();
    }
  }

  Future<void> _carregarRegioesParaMaster() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('regioes_venda')
          .where('ativo', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> regioes = [];
      for (var doc in snap.docs) {
        regioes.add({
          'id': doc.id,
          'nome': doc['nome'],
          'localidades': doc['localidades'] ?? [],
        });
      }

      // Ordena alfabeticamente para ficar bonito no menu
      regioes.sort(
        (a, b) => a['nome'].toString().compareTo(b['nome'].toString()),
      );

      if (mounted) {
        setState(() => _listaRegioesMaster = regioes);
      }
    } catch (e) {
      debugPrint('Erro ao carregar regiões para o Master: $e');
    }
  }

  // O mesmo motor elástico de limpeza de texto para garantir o cruzamento
  String _padronizarTexto(String texto) {
    if (texto.isEmpty) return '';
    String t = texto.toUpperCase().trim();
    t = t.replaceAll(RegExp(r'[ÁÀÂÃÄ]'), 'A');
    t = t.replaceAll(RegExp(r'[ÉÈÊË]'), 'E');
    t = t.replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I');
    t = t.replaceAll(RegExp(r'[ÓÒÔÕÖ]'), 'O');
    t = t.replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U');
    t = t.replaceAll(RegExp(r'[Ç]'), 'C');
    return t;
  }

  Widget _construirFiltroRegiaoMaster() {
    if (!widget.isMaster || _listaRegioesMaster.isEmpty)
      return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: _filtroRegiaoSelecionada != null
              ? Colors.orange.shade50
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _filtroRegiaoSelecionada != null
                ? Colors.orange
                : Colors.grey.shade300,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: const Text(
              '👑 Visão Master: Filtrar por Região Demarcada...',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            value: _filtroRegiaoSelecionada,
            icon: Icon(
              Icons.map,
              color: _filtroRegiaoSelecionada != null
                  ? Colors.orange
                  : Colors.grey,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text(
                  '❌ Limpar Região (Usar filtro de Estado/Cidade abaixo)',
                ),
              ),
              ..._listaRegioesMaster.map((regiao) {
                return DropdownMenuItem<String>(
                  value: regiao['id'],
                  child: Text('📍 ${regiao['nome']}'),
                );
              }).toList(),
            ],
            onChanged: (novoValor) {
              setState(() {
                _filtroRegiaoSelecionada = novoValor;

                if (novoValor != null) {
                  // A GANGORRA: Limpa os filtros manuais para evitar conflito
                  _filtroUf = 'Todas';
                  _filtrosCidades = [];

                  // Carrega a malha elástica de cidades da região
                  var regiao = _listaRegioesMaster.firstWhere(
                    (r) => r['id'] == novoValor,
                  );
                  List locs = regiao['localidades'] ?? [];
                  _cidadesDaRegiaoSelecionada = locs
                      .map((l) => _padronizarTexto(l['nome'].toString()))
                      .toList();
                } else {
                  _cidadesDaRegiaoSelecionada = [];
                }
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> queryFirebase = FirebaseFirestore.instance
        .collection('clientes')
        .where('empresa_id', isEqualTo: widget.empresaId);

    if (widget.isMaster &&
        _filtroRepresentantes.isNotEmpty &&
        _filtroRepresentantes.length <= 30) {
      queryFirebase = queryFirebase.where(
        'representante_id',
        whereIn: _filtroRepresentantes,
      );
    }

    return Scaffold(
      body: Column(
        children: [
          BarraFiltrosComercial(
            empresaId: widget.empresaId,
            termoBusca: _termoBusca,
            filtroAtivo: _filtroAtivo,
            filtroStatus: _filtroStatus,
            filtroRepresentantes: _filtroRepresentantes,
            exibirFiltroVendedor: widget.isMaster,
            opcoesStatus: const [
              'Todos',
              'Aprovado',
              'Em Análise',
              'Pendente Cadastro',
              'Bloqueado',
              'Rascunho',
            ],
            onBuscaChanged: (val) =>
                setState(() => _termoBusca = val.toLowerCase()),
            onAtivoChanged: (val) => setState(() => _filtroAtivo = val!),
            onStatusChanged: (val) => setState(() => _filtroStatus = val!),
            onRepresentantesChanged: (val) =>
                setState(() => _filtroRepresentantes = val),
          ),

          // Novo bloco de filtro superpoderoso do Master
          _construirFiltroRegiaoMaster(),

          // A Gangorra Visual (Se a Região estiver selecionada, bloqueia este filtro)
          AbsorbPointer(
            absorbing: _filtroRegiaoSelecionada != null,
            child: Opacity(
              opacity: _filtroRegiaoSelecionada != null ? 0.4 : 1.0,
              child: FiltroGeograficoMulti(
                ufSelecionada: _filtroUf,
                cidadesSelecionadas: _filtrosCidades,
                onChanged: (novaUf, novasCidades) {
                  setState(() {
                    _filtroUf = novaUf;
                    _filtrosCidades = novasCidades;
                  });
                },
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: queryFirebase.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum cliente atende aos filtros.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                var docsFiltrados = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String razao = (data['razao_social'] ?? '')
                      .toString()
                      .toLowerCase();
                  String fantasia = (data['nome_fantasia'] ?? '')
                      .toString()
                      .toLowerCase();

                  String cidadeOriginal =
                      (data['cidade'] ??
                              data['cidade_fiscal'] ??
                              data['municipio'] ??
                              '')
                          .toString();
                  String ufOriginal =
                      (data['estado'] ?? data['uf_fiscal'] ?? data['uf'] ?? '')
                          .toString();

                  String ufClienteLimpa = ufOriginal.toUpperCase().trim();
                  String cidadeClienteLimpa = cidadeOriginal
                      .toUpperCase()
                      .trim();

                  String statusCreditoDB =
                      data['status_credito'] ?? 'Em Análise';
                  String statusCreditoUI =
                      (statusCreditoDB == 'Pendente Enriquecimento')
                      ? 'Pendente Cadastro'
                      : statusCreditoDB;

                  bool isRascunho = data['is_rascunho'] ?? false;
                  bool isAtivo = data['ativo'] ?? true;

                  // =========================================================
                  // O CÉREBRO GEOGRÁFICO: SEPARAÇÃO DE MASTER E VENDEDOR
                  // =========================================================
                  if (!widget.isMaster) {
                    // VENDEDOR COMUM: Só enxerga a própria rota restrita
                    if (widget.cidadesAtuacao.isEmpty) return false;
                    if (!widget.cidadesAtuacao.contains(cidadeClienteLimpa))
                      return false;
                  } else {
                    // MASTER (Sérgio)
                    if (_filtroRepresentantes.isNotEmpty &&
                        _filtroRepresentantes.length > 30) {
                      String repAtual = (data['representante_id'] ?? 'BOLSÃO')
                          .toString();
                      if (repAtual == 'Lista Clientes Importada' ||
                          repAtual.trim().isEmpty)
                        repAtual = 'BOLSÃO';
                      if (!_filtroRepresentantes.contains(repAtual))
                        return false;
                    }

                    // Se a GANGORRA DA REGIÃO estiver ativa
                    if (_filtroRegiaoSelecionada != null) {
                      String chaveMestra = _padronizarTexto(
                        '$cidadeOriginal - $ufOriginal',
                      );
                      if (!_cidadesDaRegiaoSelecionada.contains(chaveMestra))
                        return false;
                    }
                  }

                  if (razao.isEmpty || razao == 'null' || razao == 'undefined')
                    return false;

                  bool matchBusca =
                      razao.contains(_termoBusca) ||
                      fantasia.contains(_termoBusca);
                  if (!matchBusca) return false;

                  if (_filtroAtivo == 'Ativos' && !isAtivo) return false;
                  if (_filtroAtivo == 'Inativos' && isAtivo) return false;

                  if (_filtroStatus == 'Rascunho' && !isRascunho) return false;
                  if (_filtroStatus != 'Todos' && _filtroStatus != 'Rascunho') {
                    if (isRascunho || statusCreditoUI != _filtroStatus)
                      return false;
                  }

                  // Se a GANGORRA MANUAL (Estado/Cidade) estiver ativa, a Região é nula
                  if (_filtroRegiaoSelecionada == null) {
                    if (_filtroUf != 'Todas' && ufClienteLimpa != _filtroUf)
                      return false;
                    if (_filtrosCidades.isNotEmpty &&
                        !_filtrosCidades.contains(cidadeClienteLimpa))
                      return false;
                  }

                  return true;
                }).toList();

                docsFiltrados.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;

                  String ufA =
                      (dataA['estado'] ??
                              dataA['uf_fiscal'] ??
                              dataA['uf'] ??
                              '')
                          .toString()
                          .toUpperCase()
                          .trim();
                  String ufB =
                      (dataB['estado'] ??
                              dataB['uf_fiscal'] ??
                              dataB['uf'] ??
                              '')
                          .toString()
                          .toUpperCase()
                          .trim();
                  int comparaUf = ufA.compareTo(ufB);
                  if (comparaUf != 0) return comparaUf;

                  String cidA =
                      (dataA['cidade'] ??
                              dataA['cidade_fiscal'] ??
                              dataA['municipio'] ??
                              '')
                          .toString()
                          .toUpperCase()
                          .trim();
                  String cidB =
                      (dataB['cidade'] ??
                              dataB['cidade_fiscal'] ??
                              dataB['municipio'] ??
                              '')
                          .toString()
                          .toUpperCase()
                          .trim();
                  int comparaCid = cidA.compareTo(cidB);
                  if (comparaCid != 0) return comparaCid;

                  String nomeA = (dataA['razao_social'] ?? '')
                      .toString()
                      .toLowerCase();
                  String nomeB = (dataB['razao_social'] ?? '')
                      .toString()
                      .toLowerCase();
                  return nomeA.compareTo(nomeB);
                });

                if (docsFiltrados.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum cliente atende à sua combinação de filtros.',
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

                    return CardClienteRota(
                      doc: doc,
                      data: data,
                      empresaId: widget.empresaId,
                      representanteId: widget.representanteId,
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
}

// ============================================================================
// ABA 2: NOVO PROSPECTO - MODO BALCÃO
// ============================================================================
class _AbaNovoClienteBalcao extends StatefulWidget {
  final String representanteId;
  final String empresaId;
  const _AbaNovoClienteBalcao({
    required this.representanteId,
    required this.empresaId,
  });

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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'ALERTA: Empresa ${data['descricao_situacao_cadastral']}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        setState(() {
          _dadosReceita = data;
          _cnpjValidado = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('CNPJ não encontrado.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      setState(() => _buscandoCNPJ = false);
    }
  }

  Future<void> _salvarRascunho() async {
    if (_formKey.currentState!.validate() && _cnpjValidado) {
      String razaoReceita = (_dadosReceita['razao_social'] ?? '')
          .toString()
          .trim();
      if (razaoReceita.isEmpty) return;
      setState(() => _salvando = true);
      try {
        await FirebaseFirestore.instance.collection('clientes').add({
          'ativo': true,
          'is_rascunho': true,
          'representante_id': widget.representanteId,
          'status_credito': 'Pendente Cadastro',
          'data_criacao_rascunho': FieldValue.serverTimestamp(),
          'empresa_id': widget.empresaId,
          'cnpj': _cnpjCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
          'razao_social': razaoReceita,
          'nome_fantasia': _dadosReceita['nome_fantasia'] ?? '',

          // ==============================================================
          // CORREÇÃO CRÍTICA APLICADA: GRAVANDO COM AS CHAVES DEFINITIVAS
          // ==============================================================
          'cep': _dadosReceita['cep'] ?? '',
          'logradouro': _dadosReceita['logradouro'] ?? '',
          'numero': _dadosReceita['numero'] ?? '',
          'bairro': _dadosReceita['bairro'] ?? '',
          'cidade': _dadosReceita['municipio'] ?? '',
          'estado': _dadosReceita['uf'] ?? '',

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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
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
