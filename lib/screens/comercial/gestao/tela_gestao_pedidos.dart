import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:noeixo_textil_app/screens/configuracoes/tela_configuracao_checklist.dart';
import 'package:noeixo_textil_app/services/pedido_service.dart';

import 'tela_checklist_aprovacao.dart';
import 'widgets/card_pedido_aprovacao.dart';

// Importe a tela de configuração do checklist (Ajuste o caminho se necessário)

class TelaGestaoPedidos extends StatefulWidget {
  final String empresaId;
  const TelaGestaoPedidos({super.key, required this.empresaId});

  @override
  State<TelaGestaoPedidos> createState() => _TelaGestaoPedidosState();
}

class _TelaGestaoPedidosState extends State<TelaGestaoPedidos> {
  DateTime? _dataInicial;
  DateTime? _dataFinal;

  String _etapaFunilSelecionada = 'Abertos';

  // Listas de Seleção Atuais
  List<String> _regioesSelecionadas = [];
  List<String> _vendedoresSelecionados = [];
  List<String> _estadosSelecionados = [];
  List<String> _cidadesSelecionadas = [];

  final _formatadorMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );
  final _formatadorData = DateFormat('dd/MM/yyyy');

  final PedidoService _pedidoService = PedidoService();
  bool _processandoAcao = false;

  @override
  void initState() {
    super.initState();
    // Não carregamos mais tabelas fixas no initState!
    // Os filtros agora são orgânicos e construídos a partir dos pedidos na tela.
  }

  Future<void> _abrirDialogoMultiSelect({
    required String titulo,
    required List<String> opcoes,
    required List<String> selecionadosAtual,
    required Function(List<String>) aoConfirmar,
  }) async {
    List<String> tempSelecionados = List.from(selecionadosAtual);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isTodos = tempSelecionados.isEmpty;
            return AlertDialog(
              title: Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: opcoes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Nenhuma opção encontrada para o cenário atual.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          CheckboxListTile(
                            title: const Text(
                              'Selecionar Todos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            value: isTodos,
                            activeColor: Colors.indigo,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) tempSelecionados.clear();
                              });
                            },
                          ),
                          const Divider(),
                          ...opcoes.map((opcao) {
                            return CheckboxListTile(
                              title: Text(
                                opcao,
                                style: const TextStyle(fontSize: 14),
                              ),
                              value: tempSelecionados.contains(opcao),
                              activeColor: Colors.indigo,
                              onChanged: (val) {
                                setDialogState(() {
                                  val == true
                                      ? tempSelecionados.add(opcao)
                                      : tempSelecionados.remove(opcao);
                                });
                              },
                            );
                          }).toList(),
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
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    aoConfirmar(tempSelecionados);
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _selecionarData(bool isInicial) async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (escolhida != null && mounted) {
      setState(() {
        isInicial ? _dataInicial = escolhida : _dataFinal = escolhida;
      });
    }
  }

  Future<void> _chamarTelaChecklist(
    String pedidoId,
    Map<String, dynamic> dadosPedido,
  ) async {
    final bool? sucesso = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaChecklistAprovacao(
          empresaId: widget.empresaId, // <-- CORRIGIDO AQUI
          pedidoId: pedidoId,
          clienteNome: dadosPedido['clienteNome'] ?? 'Sem Nome',
          valorPedido: (dadosPedido['valorFinalCobrado'] ?? 0).toDouble(),
          tipoAprovacao: 'Comercial',
        ),
      ),
    );
    if (sucesso == true) setState(() {});
  }

  Future<void> _alterarStatusPedido(String pedidoId, String acao) async {
    setState(() => _processandoAcao = true);
    try {
      String gestorNome = FirebaseAuth.instance.currentUser?.email ?? 'Gestor';
      String novoStatusComercial = acao == 'REPROVAR'
          ? 'Cancelado'
          : 'Devolvido';

      await _pedidoService.atualizarStatusComercial(
        pedidoId: pedidoId,
        novoStatusComercial: novoStatusComercial,
        novoStatusFinanceiro: acao == 'REPROVAR'
            ? 'Cancelado'
            : 'Aguardando Comercial',
        nomeUsuarioGestor: gestorNome,
      );
    } finally {
      if (mounted) setState(() => _processandoAcao = false);
    }
  }

  Widget _construirBlocoFunil(
    String titulo,
    int qtd,
    double valor,
    Color corBase,
    String etapaAlvo,
  ) {
    bool isSelected = _etapaFunilSelecionada == etapaAlvo;
    return GestureDetector(
      onTap: () => setState(() => _etapaFunilSelecionada = etapaAlvo),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? corBase : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? corBase : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: corBase.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$qtd ped.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : corBase,
              ),
            ),
            Text(
              _formatadorMoeda.format(valor),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white70 : Colors.grey.shade600,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isModoRetrato = _dataInicial == null && _dataFinal == null;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Back-office: Torre de Controle',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest),
            tooltip: 'Configurar Regras do Checklist',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaConfiguracaoChecklist(
                    // <-- CORRIGIDO AQUI (Sem const e repassando o ID)
                    empresaId: widget.empresaId,
                    setorAcesso: 'Comercial',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pedidos_venda')
            .orderBy('dataPedido', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          var todosDocumentos = snapshot.data?.docs ?? [];

          // ====================================================================
          // 1. FILTRAGEM MESTRA (TEMPO)
          // ====================================================================
          var basePorData = todosDocumentos.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            if (!isModoRetrato) {
              DateTime? d = (data['dataPedido'] as Timestamp?)?.toDate();
              if (d != null) {
                if (_dataInicial != null && d.isBefore(_dataInicial!))
                  return false;
                if (_dataFinal != null &&
                    d.isAfter(_dataFinal!.add(const Duration(days: 1))))
                  return false;
              } else {
                return false;
              }
            }
            return true;
          }).toList();

          // ====================================================================
          // 2. EXTRAÇÃO ORGÂNICA DOS FILTROS (A MÁGICA DA CASCATA)
          // ====================================================================
          Set<String> setRegioes = {};
          Set<String> setVendedores = {};
          Set<String> setEstados = {};
          Set<String> setCidades = {};

          for (var doc in basePorData) {
            var data = doc.data() as Map<String, dynamic>;
            String r = (data['regiao'] ?? '').toString().trim();
            String v = (data['representanteNome'] ?? '').toString().trim();
            String e = (data['estado'] ?? data['uf'] ?? '').toString().trim();
            String c = (data['cidade'] ?? '').toString().trim();

            bool passaReg =
                _regioesSelecionadas.isEmpty ||
                _regioesSelecionadas.contains(r);
            bool passaVend =
                _vendedoresSelecionados.isEmpty ||
                _vendedoresSelecionados.contains(v);
            bool passaEst =
                _estadosSelecionados.isEmpty ||
                _estadosSelecionados.contains(e);

            // Popula Regiões (influenciado por Vendedor)
            if (r.isNotEmpty && passaVend) setRegioes.add(r);

            // Popula Vendedores (influenciado por Região)
            if (v.isNotEmpty && passaReg) setVendedores.add(v);

            // Popula Estados (influenciado por Região e Vendedor)
            if (e.isNotEmpty && passaReg && passaVend) setEstados.add(e);

            // Popula Cidades (influenciado por Região, Vendedor e Estado)
            if (c.isNotEmpty && passaReg && passaVend && passaEst)
              setCidades.add(c);
          }

          List<String> opcoesRegioes = setRegioes.toList()..sort();
          List<String> opcoesVendedores = setVendedores.toList()..sort();
          List<String> opcoesEstados = setEstados.toList()..sort();
          List<String> opcoesCidades = setCidades.toList()..sort();

          // ====================================================================
          // 3. APLICAÇÃO FINAL DE TODOS OS FILTROS CRUZADOS PARA A LISTA
          // ====================================================================
          var baseFiltradaFinal = basePorData.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String r = (data['regiao'] ?? '').toString().trim();
            String v = (data['representanteNome'] ?? '').toString().trim();
            String e = (data['estado'] ?? data['uf'] ?? '').toString().trim();
            String c = (data['cidade'] ?? '').toString().trim();

            if (_regioesSelecionadas.isNotEmpty &&
                !_regioesSelecionadas.contains(r))
              return false;
            if (_vendedoresSelecionados.isNotEmpty &&
                !_vendedoresSelecionados.contains(v))
              return false;
            if (_estadosSelecionados.isNotEmpty &&
                !_estadosSelecionados.contains(e))
              return false;
            if (_cidadesSelecionadas.isNotEmpty &&
                !_cidadesSelecionadas.contains(c))
              return false;

            return true;
          }).toList();

          // Distribuição nos funis
          List docsAbertos = [],
              docsAvaliacao = [],
              docsPendencias = [],
              docsProducao = [],
              docsLogistica = [];
          double valAbertos = 0,
              valAvaliacao = 0,
              valPendencias = 0,
              valProducao = 0,
              valLogistica = 0;

          for (var doc in baseFiltradaFinal) {
            var d = doc.data() as Map<String, dynamic>;
            String stCom = d['status_comercial'] ?? '';
            String stPcp = d['status_pcp'] ?? '';
            String stFin = d['status_financeiro'] ?? '';
            String stLog = d['status_producao_logistica'] ?? '';
            double valor = (d['valorFinalCobrado'] ?? 0).toDouble();

            bool isPendenteErro =
                (stCom == 'Devolvido' ||
                stCom == 'Cancelado' ||
                stPcp == 'Devolvido' ||
                stPcp == 'Cancelado' ||
                stFin == 'Devolvido' ||
                stFin == 'Cancelado' ||
                stFin == 'Rejeitado');
            bool isAprovadoGeral =
                (stCom == 'Aprovado' &&
                stPcp == 'Aprovado' &&
                stFin == 'Aprovado');
            bool isLogistica =
                (stLog == 'Faturado' ||
                stLog == 'Despachado' ||
                stLog == 'Entregue');
            bool isAguardandoCliente =
                (stCom == 'Pendente Cliente' ||
                stCom == 'Em Digitação' ||
                stCom == 'AGUARDANDO APROVAÇÃO DO CLIENTE');

            if (isPendenteErro) {
              docsPendencias.add(doc);
              valPendencias += valor;
            } else if (isLogistica) {
              docsLogistica.add(doc);
              valLogistica += valor;
            } else if (isAprovadoGeral) {
              docsProducao.add(doc);
              valProducao += valor;
            } else if (stCom == 'Aprovado') {
              docsAvaliacao.add(doc);
              valAvaliacao += valor;
            } else if (!isAguardandoCliente) {
              docsAbertos.add(doc);
              valAbertos += valor;
            }
          }

          List listaExibicao = [];
          if (_etapaFunilSelecionada == 'Abertos')
            listaExibicao = docsAbertos;
          else if (_etapaFunilSelecionada == 'Avaliacao')
            listaExibicao = docsAvaliacao;
          else if (_etapaFunilSelecionada == 'Pendencias')
            listaExibicao = docsPendencias;
          else if (_etapaFunilSelecionada == 'Producao')
            listaExibicao = docsProducao;
          else if (_etapaFunilSelecionada == 'Logistica')
            listaExibicao = docsLogistica;

          return Column(
            children: [
              // ========================================================
              // PAINEL DE FILTROS ORGÂNICOS
              // ========================================================
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // LINHA 1: TEMPO
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selecionarData(true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'De (Data)',
                                isDense: true,
                              ),
                              child: Text(
                                _dataInicial == null
                                    ? 'Modo Retrato (Agora)'
                                    : _formatadorData.format(_dataInicial!),
                                style: TextStyle(
                                  color: _dataInicial == null
                                      ? Colors.indigo
                                      : Colors.black,
                                  fontWeight: _dataInicial == null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selecionarData(false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Até (Data)',
                                isDense: true,
                              ),
                              child: Text(
                                _dataFinal == null
                                    ? 'Modo Retrato (Agora)'
                                    : _formatadorData.format(_dataFinal!),
                                style: TextStyle(
                                  color: _dataFinal == null
                                      ? Colors.indigo
                                      : Colors.black,
                                  fontWeight: _dataFinal == null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!isModoRetrato)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            tooltip: 'Voltar para Modo Retrato',
                            onPressed: () => setState(() {
                              _dataInicial = null;
                              _dataFinal = null;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // LINHA 2: REGIÃO E VENDEDOR
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _abrirDialogoMultiSelect(
                              titulo: 'Regiões Identificadas',
                              opcoes: opcoesRegioes,
                              selecionadosAtual: _regioesSelecionadas,
                              aoConfirmar: (s) => setState(() {
                                _regioesSelecionadas = s;
                                _estadosSelecionados.clear();
                                _cidadesSelecionadas.clear();
                              }),
                            ),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Região',
                                prefixIcon: Icon(Icons.map, size: 16),
                                isDense: true,
                              ),
                              child: Text(
                                _regioesSelecionadas.isEmpty
                                    ? 'Todas'
                                    : _regioesSelecionadas.join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _abrirDialogoMultiSelect(
                              titulo: 'Vendedores Identificados',
                              opcoes: opcoesVendedores,
                              selecionadosAtual: _vendedoresSelecionados,
                              aoConfirmar: (s) => setState(() {
                                _vendedoresSelecionados = s;
                                _estadosSelecionados.clear();
                                _cidadesSelecionadas.clear();
                              }),
                            ),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Vendedor',
                                prefixIcon: Icon(Icons.person, size: 16),
                                isDense: true,
                              ),
                              child: Text(
                                _vendedoresSelecionados.isEmpty
                                    ? 'Todos'
                                    : _vendedoresSelecionados.join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // LINHA 3: ESTADO E CIDADE
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _abrirDialogoMultiSelect(
                              titulo: 'Estados Identificados',
                              opcoes: opcoesEstados,
                              selecionadosAtual: _estadosSelecionados,
                              aoConfirmar: (s) => setState(() {
                                _estadosSelecionados = s;
                                _cidadesSelecionadas.clear();
                              }),
                            ),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Estado',
                                prefixIcon: Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                ),
                                isDense: true,
                              ),
                              child: Text(
                                _estadosSelecionados.isEmpty
                                    ? 'Todos'
                                    : _estadosSelecionados.join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _abrirDialogoMultiSelect(
                              titulo: 'Cidades Identificadas',
                              opcoes: opcoesCidades,
                              selecionadosAtual: _cidadesSelecionadas,
                              aoConfirmar: (s) =>
                                  setState(() => _cidadesSelecionadas = s),
                            ),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Cidade',
                                prefixIcon: Icon(Icons.location_city, size: 16),
                                isDense: true,
                              ),
                              child: Text(
                                _cidadesSelecionadas.isEmpty
                                    ? 'Todas'
                                    : _cidadesSelecionadas.join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ========================================================
              // FUNIL GERENCIAL
              // ========================================================
              Container(
                height: 140,
                color: Colors.blueGrey.shade50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  children: [
                    _construirBlocoFunil(
                      '1. ABERTOS\n(Na minha mesa)',
                      docsAbertos.length,
                      valAbertos,
                      Colors.blue.shade700,
                      'Abertos',
                    ),
                    _construirBlocoFunil(
                      '2. AVALIAÇÃO\n(Radar Interno)',
                      docsAvaliacao.length,
                      valAvaliacao,
                      Colors.amber.shade700,
                      'Avaliacao',
                    ),
                    _construirBlocoFunil(
                      '3. PENDÊNCIAS\n(Intervenção)',
                      docsPendencias.length,
                      valPendencias,
                      Colors.red.shade700,
                      'Pendencias',
                    ),
                    _construirBlocoFunil(
                      '4. PRODUÇÃO\n(Fábrica Rodando)',
                      docsProducao.length,
                      valProducao,
                      Colors.orange.shade800,
                      'Producao',
                    ),
                    _construirBlocoFunil(
                      '5. LOGÍSTICA\n(Faturamento)',
                      docsLogistica.length,
                      valLogistica,
                      Colors.green.shade700,
                      'Logistica',
                    ),
                  ],
                ),
              ),

              // ========================================================
              // LISTA DE PEDIDOS
              // ========================================================
              Expanded(
                child: listaExibicao.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum pedido na etapa "$_etapaFunilSelecionada" atende aos filtros aplicados.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: listaExibicao.length,
                        itemBuilder: (context, index) {
                          var doc = listaExibicao[index];
                          return CardPedidoAprovacao(
                            pedidoId: doc.id,
                            data: doc.data() as Map<String, dynamic>,
                            processandoAcao: _processandoAcao,
                            onDevolver: () =>
                                _alterarStatusPedido(doc.id, 'DEVOLVER'),
                            onReprovar: () =>
                                _alterarStatusPedido(doc.id, 'REPROVAR'),
                            onAprovar: () => _chamarTelaChecklist(
                              doc.id,
                              doc.data() as Map<String, dynamic>,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
