import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../comercial/tela_catalogo_vendas.dart';
import 'tela_preview_pedido_pdf.dart';

class FormPedidoVenda extends StatefulWidget {
  final String empresaId;
  final String clienteId;
  final String clienteNome;
  final String regiao;
  final String whatsappCliente;

  final String? pedidoEdicaoId;
  final Map<String, dynamic>? dadosEdicao;

  const FormPedidoVenda({
    super.key,
    required this.empresaId,
    required this.clienteId,
    required this.clienteNome,
    required this.regiao,
    this.whatsappCliente = '',
    this.pedidoEdicaoId,
    this.dadosEdicao,
  });

  @override
  State<FormPedidoVenda> createState() => _FormPedidoVendaState();
}

class _FormPedidoVendaState extends State<FormPedidoVenda> {
  // ===================================================================
  // 1. VARIÁVEIS DE ESTADO
  // ===================================================================
  bool _carregandoPolitica = true;
  bool _isMaster = false;
  Map<String, dynamic>? _politicaComercial;

  double _comissaoAtualCalculada = 0.0;
  double _limiteDescontoAtual = 100.0;
  bool _vendaBloqueada = false;
  bool _requerAprovacaoDiretoria = false;

  String _tipoVenda = 'PRONTA ENTREGA';
  List<Map<String, dynamic>> _carrinhoItens = [];
  bool _preparandoPedido = false;

  final TextEditingController _descontoExtraCtrl = TextEditingController(
    text: '0.0',
  );
  final TextEditingController _observacoesCtrl = TextEditingController();

  double _descontoExtraPerc = 0.0;
  bool _mostrarComissao = false;

  DateTime? _tempoExpiracao;
  Timer? _cronometro;
  String _tempoRestanteStr = "03:00:00";

  List<Map<String, dynamic>> _listaFormasPagamento = [];
  List<Map<String, dynamic>> _listaCondicoesPagamento = [];
  String? _formaPagamentoSelecionada;
  String? _condicaoPagamentoSelecionada;
  DateTime? _dataPrevistaEntrega;

  String _nomeVendedorLogado = 'Vendedor Não Identificado';
  String _mensagemDevolucao = '';
  String _quemDevolveu = '';

  // === NOVA VARIÁVEL DO AUTO-SAVE ===
  String? _rascunhoPedidoId;

  @override
  void initState() {
    super.initState();
    _carregarDadosFinanceiros();
    _identificarVendedorLogado();
    _inicializarMotorComercial();

    if (widget.pedidoEdicaoId != null) {
      _rascunhoPedidoId = widget
          .pedidoEdicaoId; // Se está editando, o rascunho é o próprio pedido
    }

    if (widget.dadosEdicao != null) {
      final dadosAntigos = widget.dadosEdicao!;

      String statusApp =
          dadosAntigos['status_comercial'] ?? dadosAntigos['status'] ?? '';
      if (statusApp == 'Devolvido' || statusApp == 'Devolvido pelo Cliente') {
        _quemDevolveu = statusApp == 'Devolvido pelo Cliente'
            ? 'Cliente'
            : 'Gestor';
        List historico = dadosAntigos['historico_mensagens'] ?? [];
        if (historico.isNotEmpty) {
          _mensagemDevolucao = historico.last['mensagem'] ?? '';
        }
      }

      _tipoVenda = dadosAntigos['tipoVenda'] ?? 'PRONTA ENTREGA';
      _observacoesCtrl.text = dadosAntigos['observacoes'] ?? '';

      if (dadosAntigos['itens'] != null) {
        _carrinhoItens = List<Map<String, dynamic>>.from(dadosAntigos['itens']);
      }

      _formaPagamentoSelecionada = dadosAntigos['formaPagamento'];
      _condicaoPagamentoSelecionada = dadosAntigos['condicaoPagamento'];

      if (dadosAntigos['dataEntregaPrevista'] != null &&
          dadosAntigos['dataEntregaPrevista'] is Timestamp) {
        _dataPrevistaEntrega =
            (dadosAntigos['dataEntregaPrevista'] as Timestamp).toDate();
      }

      if (_carrinhoItens.isNotEmpty) {
        _iniciarCronometro();
      }
    }

    // Ouve as observações para salvar o rascunho se o vendedor digitar algo longo
    _observacoesCtrl.addListener(() {
      _acionarSalvaVidasSilencioso();
    });
  }

  @override
  void dispose() {
    _cronometro?.cancel();
    _descontoExtraCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  // ===================================================================
  // 2. MOTOR DO AUTO-SAVE (SALVA-VIDAS SILENCIOSO)
  // ===================================================================
  Timer? _debounceTimer;

  void _acionarSalvaVidasSilencioso() {
    // Evita bombardear o banco de dados. Só salva após 2 segundos de inatividade de toques.
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _executarGravacaoRascunho();
    });
  }

  Future<void> _executarGravacaoRascunho() async {
    // Só cria rascunho se tiver pelo menos um item ou se já existir um ID
    if (_carrinhoItens.isEmpty && _rascunhoPedidoId == null) return;

    try {
      Map<String, dynamic> payloadRascunho = {
        'empresa_id': widget.empresaId,
        'clienteId': widget.clienteId,
        'clienteNome': widget.clienteNome,
        'regiao': widget.regiao,
        'representanteNome': _nomeVendedorLogado,
        'whatsapp': widget.whatsappCliente,
        'tipoVenda': _tipoVenda,
        'formaPagamento': _formaPagamentoSelecionada,
        'condicaoPagamento': _condicaoPagamentoSelecionada,
        'dataEntregaPrevista': _dataPrevistaEntrega,
        'valorTotalTabela': _valorTotalTabelaPura,
        'valorFinalCobrado': _valorFinalComDescontoExtra,
        'descontoRealAplicadoPerc': _descontoRealTotalPerc,
        'comissaoPrevistaPerc': _comissaoAtualCalculada,
        'comissaoPrevistaValor':
            _valorFinalComDescontoExtra * (_comissaoAtualCalculada / 100),
        'itens': _carrinhoItens,
        'observacoes': _observacoesCtrl.text.trim(),
        'status_comercial': 'Rascunho', // Etiqueta de proteção
        'is_rascunho': true,
        'dataPedido': FieldValue.serverTimestamp(),
      };

      if (_rascunhoPedidoId == null) {
        // Nasce o rascunho
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('pedidos_venda')
            .add(payloadRascunho);
        _rascunhoPedidoId = docRef.id;
      } else {
        // Atualiza o rascunho existente
        await FirebaseFirestore.instance
            .collection('pedidos_venda')
            .doc(_rascunhoPedidoId)
            .update(payloadRascunho);
      }
    } catch (e) {
      debugPrint('Erro no Auto-Save: $e');
    }
  }

  // ===================================================================
  // 3. NOVO CÉREBRO: INICIALIZAÇÃO E CÁLCULO
  // ===================================================================
  Future<void> _inicializarMotorComercial() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) return;

      final db = FirebaseFirestore.instance;

      final vendedorSnap = await db
          .collection('vendedores')
          .where('email', isEqualTo: user.email)
          .where('empresa_id', isEqualTo: widget.empresaId)
          .limit(1)
          .get();

      if (vendedorSnap.docs.isNotEmpty) {
        final vendedorData = vendedorSnap.docs.first.data();
        _isMaster = vendedorData['atendimento_global'] ?? false;
        final String? politicaId = vendedorData['politica_comercial_id'];

        if (!_isMaster && politicaId != null) {
          final politicaSnap = await db
              .collection('politicas_comerciais')
              .doc(politicaId)
              .get();
          if (politicaSnap.exists) {
            _politicaComercial = politicaSnap.data();
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao inicializar Motor Comercial: $e');
    } finally {
      if (mounted) {
        setState(() {
          _carregandoPolitica = false;
          _processarMatematicaDoCarrinho();
        });
      }
    }
  }

  void _processarMatematicaDoCarrinho() {
    if (_carregandoPolitica) return;

    double descontoAtual = _descontoRealTotalPerc;
    double valorLiquido = _valorFinalComDescontoExtra;

    if (_politicaComercial == null || _isMaster) {
      setState(() {
        _comissaoAtualCalculada = 0.0;
        _limiteDescontoAtual = 100.0;
        _vendaBloqueada = false;
        _requerAprovacaoDiretoria = false;
      });
      _acionarSalvaVidasSilencioso(); // Aciona o auto-save ao recalcular
      return;
    }

    final pol = _politicaComercial!;

    double comissaoBase = 0.0;
    if (pol['tipo_comissao'] == 'Fixa') {
      comissaoBase = (pol['comissao_fixa'] ?? 0.0).toDouble();
    } else if (pol['faixas_escalonadas'] != null) {
      List faixas = pol['faixas_escalonadas'];
      for (var f in faixas) {
        double dIni = (f['desconto_inicial'] ?? 0.0).toDouble();
        double dFim = (f['desconto_final'] ?? 0.0).toDouble();
        if (descontoAtual >= dIni && descontoAtual <= dFim) {
          comissaoBase = (f['percentual_comissao'] ?? 0.0).toDouble();
          break;
        }
      }
    }

    String? condicaoId;
    if (_condicaoPagamentoSelecionada != null) {
      final condEncontrada = _listaCondicoesPagamento.firstWhere(
        (e) => e['nome'] == _condicaoPagamentoSelecionada,
        orElse: () => {},
      );
      condicaoId = condEncontrada['id'];
    }

    double modComissaoPrazo = 0.0;
    double modDescontoPrazo = 0.0;
    if (condicaoId != null && pol['modificadores_pagamento'] != null) {
      var mods = pol['modificadores_pagamento'];
      if (mods.containsKey(condicaoId)) {
        modComissaoPrazo = (mods[condicaoId]['comissao'] ?? 0.0).toDouble();
        modDescontoPrazo = (mods[condicaoId]['desconto'] ?? 0.0).toDouble();
      }
    }

    double modComissaoVol = 0.0;
    double modDescontoVol = 0.0;
    if (pol['faixas_volume'] != null) {
      List faixasVol = pol['faixas_volume'];
      for (var f in faixasVol) {
        double vIni = (f['valor_inicial'] ?? 0.0).toDouble();
        double vFim = (f['valor_final'] ?? 0.0).toDouble();
        if (valorLiquido >= vIni && valorLiquido <= vFim) {
          modComissaoVol = (f['modificador_comissao'] ?? 0.0).toDouble();
          modDescontoVol = (f['modificador_desconto'] ?? 0.0).toDouble();
          break;
        }
      }
    }

    double limiteDescontoBase = (pol['desconto_maximo_permitido'] ?? 0.0)
        .toDouble();
    double limiteFinal = limiteDescontoBase + modDescontoPrazo + modDescontoVol;
    double comissaoFinal = comissaoBase + modComissaoPrazo + modComissaoVol;

    if (comissaoFinal < 0.0) comissaoFinal = 0.0;
    if (limiteFinal < 0.0) limiteFinal = 0.0;
    if (limiteFinal > 100.0) limiteFinal = 100.0;

    bool bloqueada = false;
    bool diretoria = false;

    if (descontoAtual > limiteFinal) {
      String acao = pol['acao_extrapolacao'] ?? 'Bloquear Venda';
      if (acao == 'Bloquear Venda') {
        bloqueada = true;
      } else if (acao == 'Enviar Diretoria') {
        diretoria = true;
      }
    }

    if (mounted) {
      setState(() {
        _limiteDescontoAtual = limiteFinal;
        _comissaoAtualCalculada = comissaoFinal;
        _vendaBloqueada = bloqueada;
        _requerAprovacaoDiretoria = diretoria;
      });
      _acionarSalvaVidasSilencioso(); // Aciona o auto-save sempre que a matemática mudar
    }
  }

  // ===================================================================
  // 4. FUNÇÕES ORIGINAIS
  // ===================================================================
  Future<void> _identificarVendedorLogado() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        final email = user.email!;
        final queryVendedores = await FirebaseFirestore.instance
            .collection('vendedores')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (queryVendedores.docs.isNotEmpty) {
          final data = queryVendedores.docs.first.data();
          if (data.containsKey('nome_vendedor') &&
              data['nome_vendedor'] != null) {
            if (mounted)
              setState(() => _nomeVendedorLogado = data['nome_vendedor']);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao identificar vendedor logado: $e');
    }
  }

  Future<void> _carregarDadosFinanceiros() async {
    try {
      final db = FirebaseFirestore.instance;
      final formasSnap = await db
          .collection('formas_pagamento')
          .where('ativo', isEqualTo: true)
          .get();
      final condicoesSnap = await db
          .collection('condicoes_pagamento')
          .where('ativo', isEqualTo: true)
          .get();
      if (mounted) {
        setState(() {
          _listaFormasPagamento = formasSnap.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          _listaCondicoesPagamento = condicoesSnap.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar financeiro: $e');
    }
  }

  Future<void> _selecionarDataEntrega() async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: _dataPrevistaEntrega ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (escolhida != null && mounted) {
      setState(() => _dataPrevistaEntrega = escolhida);
      _acionarSalvaVidasSilencioso();
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  void _iniciarCronometro() {
    if (_tempoExpiracao == null) {
      _tempoExpiracao = DateTime.now().add(const Duration(hours: 3));
      _cronometro = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        final agora = DateTime.now();
        if (agora.isAfter(_tempoExpiracao!)) {
          timer.cancel();
          setState(() => _tempoRestanteStr = "EXPIRADO");
        } else {
          final diff = _tempoExpiracao!.difference(agora);
          String h = diff.inHours.toString().padLeft(2, '0');
          String m = (diff.inMinutes % 60).toString().padLeft(2, '0');
          String s = (diff.inSeconds % 60).toString().padLeft(2, '0');
          setState(() => _tempoRestanteStr = "$h:$m:$s");
        }
      });
    }
  }

  Future<void> _abrirCatalogoParaAdicionarItem() async {
    List<String> idsNoCarrinho = _carrinhoItens
        .map((item) => item['produtoId'].toString())
        .toList();
    final itemSelecionado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaCatalogoVendas(
          empresaId: widget.empresaId,
          produtosNoCarrinho: idsNoCarrinho,
        ),
      ),
    );

    if (itemSelecionado != null && itemSelecionado is Map<String, dynamic>) {
      bool jaExiste = _carrinhoItens.any(
        (item) => item['produtoId'] == itemSelecionado['produtoId'],
      );
      if (jaExiste) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Esta referência já está no carrinho.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (_tipoVenda == 'PRONTA ENTREGA') {
        try {
          await FirebaseFirestore.instance
              .collection('produtos')
              .doc(itemSelecionado['produtoId'])
              .update({
                'estoqueComprometido': FieldValue.increment(
                  itemSelecionado['quantidadeTotal'],
                ),
              });
        } catch (e) {}
      }
      _iniciarCronometro();
      setState(() => _carrinhoItens.add(itemSelecionado));
      _processarMatematicaDoCarrinho();
    }
  }

  Future<void> _removerItem(String idTemporario) async {
    var item = _carrinhoItens.firstWhere(
      (e) => e['idTemporario'] == idTemporario,
    );
    if (_tipoVenda == 'PRONTA ENTREGA') {
      try {
        await FirebaseFirestore.instance
            .collection('produtos')
            .doc(item['produtoId'])
            .update({
              'estoqueComprometido': FieldValue.increment(
                -item['quantidadeTotal'],
              ),
            });
      } catch (e) {}
    }
    setState(() {
      _carrinhoItens.removeWhere((e) => e['idTemporario'] == idTemporario);
      if (_carrinhoItens.isEmpty) {
        _cronometro?.cancel();
        _tempoExpiracao = null;
      }
    });
    _processarMatematicaDoCarrinho();
  }

  Future<void> _editarItemDoCarrinho(int index) async {
    final itemAtual = _carrinhoItens[index];
    final itemEditado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaCatalogoVendas(
          empresaId: widget.empresaId,
          itemParaEditar: itemAtual,
        ),
      ),
    );

    if (itemEditado != null && itemEditado is Map<String, dynamic>) {
      if (_tipoVenda == 'PRONTA ENTREGA') {
        int diferenca =
            itemEditado['quantidadeTotal'] - itemAtual['quantidadeTotal'];
        if (diferenca != 0) {
          try {
            await FirebaseFirestore.instance
                .collection('produtos')
                .doc(itemAtual['produtoId'])
                .update({
                  'estoqueComprometido': FieldValue.increment(diferenca),
                });
          } catch (e) {}
        }
      }
      setState(() {
        _carrinhoItens[index] = itemEditado;
      });
      _processarMatematicaDoCarrinho();
    }
  }

  Future<bool?> _mostrarAlertaDeSaida() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sair do Pedido?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: const Text(
            'Você possui itens lançados neste pedido.\n\nFique tranquilo, nós salvamos o seu progresso automaticamente como "Rascunho".\n\nDeseja fechar esta tela?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'VOLTAR AO PEDIDO',
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SAIR', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  double get _valorTotalTabelaPura => _carrinhoItens.fold(
    0.0,
    (soma, item) => soma + (item['quantidadeTotal'] * item['precoTabela']),
  );
  double get _valorParcialNegociadoNasPecas => _carrinhoItens.fold(
    0.0,
    (soma, item) => soma + (item['quantidadeTotal'] * item['precoVendido']),
  );
  double get _valorFinalComDescontoExtra =>
      _valorParcialNegociadoNasPecas * (1 - (_descontoExtraPerc / 100));

  double get _descontoRealTotalPerc {
    if (_valorTotalTabelaPura == 0) return 0.0;
    return 100 - ((_valorFinalComDescontoExtra / _valorTotalTabelaPura) * 100);
  }

  Color _getCorTermometro() {
    if (_vendaBloqueada) return Colors.red.shade700;
    if (_requerAprovacaoDiretoria) return Colors.orange.shade700;

    double desc = _descontoRealTotalPerc;
    if (desc <= 0.01) return Colors.blueGrey;
    if (desc <= 10.01) return Colors.blue.shade600;
    return Colors.teal;
  }

  void _revisarPedido() {
    if (_carrinhoItens.isEmpty) return;

    if (_formaPagamentoSelecionada == null ||
        _condicaoPagamentoSelecionada == null ||
        _dataPrevistaEntrega == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Preencha a Data de Entrega e as Condições Financeiras!',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_vendaBloqueada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🚫 Venda bloqueada. O desconto ultrapassa o limite permitido.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _preparandoPedido = true);

    String statusComercial = 'Aberto';
    String statusPrevistoVisivel = 'ABERTO';

    if (_requerAprovacaoDiretoria) {
      statusComercial = 'Pendente Diretoria';
      statusPrevistoVisivel = 'SOB ANÁLISE (DIRETORIA)';
    }

    Map<String, dynamic> pacoteParaPDF = {
      // Usa o ID do rascunho invisível para sobrescrever o pedido final
      if (_rascunhoPedidoId != null) 'pedidoId': _rascunhoPedidoId,
      'empresa_id': widget.empresaId,
      'clienteId': widget.clienteId,
      'clienteNome': widget.clienteNome,
      'regiao': widget.regiao,
      'representanteNome': _nomeVendedorLogado,
      'whatsapp': widget.whatsappCliente,
      'tipoVenda': _tipoVenda,
      'formaPagamento': _formaPagamentoSelecionada,
      'condicaoPagamento': _condicaoPagamentoSelecionada,
      'dataEntregaPrevista': _dataPrevistaEntrega,
      'dataEntregaStr': _formatarData(_dataPrevistaEntrega!),
      'valorTotalTabela': _valorTotalTabelaPura,
      'valorFinalCobrado': _valorFinalComDescontoExtra,
      'descontoRealAplicadoPerc': _descontoRealTotalPerc,
      'comissaoPrevistaPerc': _comissaoAtualCalculada,
      'comissaoPrevistaValor':
          _valorFinalComDescontoExtra * (_comissaoAtualCalculada / 100),
      'itens': _carrinhoItens,
      'statusPrevisto': statusPrevistoVisivel,
      'observacoes': _observacoesCtrl.text.trim(),
      'historico_mensagens': widget.dadosEdicao != null
          ? (widget.dadosEdicao!['historico_mensagens'] ?? [])
          : [],
      'status_comercial': statusComercial,
      'status_pcp': 'Aguardando',
      'status_financeiro': 'Aguardando',
      'is_rascunho': false, // Limpa o status de rascunho
    };

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _preparandoPedido = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TelaPreviewPedidoPDF(dadosPedido: pacoteParaPDF),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoPolitica) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Color corAcao = _getCorTermometro();
    bool podeSairDireto = _carrinhoItens.isEmpty;

    return PopScope(
      canPop: podeSairDireto,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final confirmouSaida = await _mostrarAlertaDeSaida();
        if (confirmouSaida == true && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text(
            'Carrinho de Vendas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            if (_mensagemDevolucao.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade50,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.assignment_return, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Atenção! Instrução do $_quemDevolveu:',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _mensagemDevolucao,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (!_isMaster && _politicaComercial != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: _vendaBloqueada
                    ? Colors.red.shade100
                    : (_requerAprovacaoDiretoria
                          ? Colors.orange.shade100
                          : Colors.teal.shade50),
                child: Row(
                  children: [
                    Icon(
                      _vendaBloqueada
                          ? Icons.block
                          : (_requerAprovacaoDiretoria
                                ? Icons.warning_amber
                                : Icons.verified_user),
                      color: _vendaBloqueada
                          ? Colors.red
                          : (_requerAprovacaoDiretoria
                                ? Colors.orange.shade900
                                : Colors.teal),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teto Limite: ${_limiteDescontoAtual.toStringAsFixed(1)}% | Comissão Atual: ${_comissaoAtualCalculada.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (_vendaBloqueada)
                            const Text(
                              'O desconto atual ultrapassou o teto permitido.',
                              style: TextStyle(color: Colors.red, fontSize: 11),
                            ),
                          if (_requerAprovacaoDiretoria)
                            const Text(
                              'Desconto alto. Requer autorização da Diretoria.',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'CLIENTE: ${widget.clienteNome}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.indigo,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_tempoExpiracao != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer,
                                size: 14,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _tempoRestanteStr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Text(
                    'Região Comercial: ${widget.regiao}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('PRONTA ENTREGA'),
                        selected: _tipoVenda == 'PRONTA ENTREGA',
                        onSelected: _carrinhoItens.isEmpty
                            ? (val) {
                                if (val) {
                                  setState(() => _tipoVenda = 'PRONTA ENTREGA');
                                  _acionarSalvaVidasSilencioso();
                                }
                              }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('PROGRAMADA'),
                        selected: _tipoVenda == 'PROGRAMADA',
                        onSelected: _carrinhoItens.isEmpty
                            ? (val) {
                                if (val) {
                                  setState(() => _tipoVenda = 'PROGRAMADA');
                                  _acionarSalvaVidasSilencioso();
                                }
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.storefront, size: 24),
                  label: const Text(
                    '➕ ABRIR CATÁLOGO DE VENDAS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: _abrirCatalogoParaAdicionarItem,
                ),
              ),
            ),

            Expanded(
              child: _carrinhoItens.isEmpty
                  ? const Center(
                      child: Text(
                        'Carrinho vazio. Abra o catálogo para lançar itens.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _carrinhoItens.length,
                            itemBuilder: (context, index) {
                              final item = _carrinhoItens[index];
                              double totalItemTabela =
                                  item['quantidadeTotal'] * item['precoTabela'];
                              double totalItemVendido =
                                  item['quantidadeTotal'] *
                                  item['precoVendido'];
                              bool temDescontoNaPeca =
                                  item['precoVendido'] < item['precoTabela'];

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  onTap: () => _editarItemDoCarrinho(index),
                                  leading: (item['fotoBase64'] != null)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: Image.memory(
                                            base64Decode(item['fotoBase64']),
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.checkroom,
                                          color: Colors.teal,
                                          size: 40,
                                        ),
                                  title: Text(
                                    item['nome'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Qtd: ${item['quantidadeTotal']} pçs\n(Toque para editar)',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (temDescontoNaPeca)
                                            Text(
                                              'R\$ ${totalItemTabela.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                          Text(
                                            'R\$ ${totalItemVendido.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: temDescontoNaPeca
                                                  ? Colors.orange.shade700
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _removerItem(item['idTemporario']),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          if (_carrinhoItens.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.white,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Condições Comerciais e Entrega',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                  const Divider(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          decoration: const InputDecoration(
                                            labelText: 'Forma Pgto',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          value: _formaPagamentoSelecionada,
                                          items: _listaFormasPagamento
                                              .map(
                                                (f) => DropdownMenuItem<String>(
                                                  value: f['nome'],
                                                  child: Text(
                                                    f['nome'],
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (val) {
                                            setState(
                                              () => _formaPagamentoSelecionada =
                                                  val,
                                            );
                                            _acionarSalvaVidasSilencioso();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          decoration: const InputDecoration(
                                            labelText: 'Prazo',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          value: _condicaoPagamentoSelecionada,
                                          items: _listaCondicoesPagamento
                                              .map(
                                                (c) => DropdownMenuItem<String>(
                                                  value: c['nome'],
                                                  child: Text(
                                                    c['nome'],
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (val) {
                                            setState(
                                              () =>
                                                  _condicaoPagamentoSelecionada =
                                                      val,
                                            );
                                            _processarMatematicaDoCarrinho();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: _selecionarDataEntrega,
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Data Prevista para Entrega',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _dataPrevistaEntrega == null
                                                ? 'Selecionar Data...'
                                                : _formatarData(
                                                    _dataPrevistaEntrega!,
                                                  ),
                                            style: TextStyle(
                                              color:
                                                  _dataPrevistaEntrega == null
                                                  ? Colors.red
                                                  : Colors.black87,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                            color: Colors.indigo,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _observacoesCtrl,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Observações (Sairá impresso no PDF)',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),

            if (_carrinhoItens.isNotEmpty)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: corAcao.withOpacity(0.1),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Tabela: R\$ ${_valorTotalTabelaPura.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  Text(
                                    'Total Final: R\$ ${_valorFinalComDescontoExtra.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: corAcao,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 130,
                              child: TextFormField(
                                controller: _descontoExtraCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: corAcao,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Desc. Extra (%)',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: Icon(
                                    Icons.percent,
                                    size: 14,
                                    color: corAcao,
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(
                                    () => _descontoExtraPerc =
                                        double.tryParse(
                                          val.replaceAll(',', '.'),
                                        ) ??
                                        0.0,
                                  );
                                  _processarMatematicaDoCarrinho();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        color: corAcao.withOpacity(0.2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _vendaBloqueada
                                      ? Icons.lock
                                      : Icons.analytics,
                                  color: corAcao,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Desconto Real: ${_descontoRealTotalPerc.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: corAcao,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                if (_mostrarComissao && !_vendaBloqueada)
                                  Text(
                                    'Comissão: ${_comissaoAtualCalculada.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: corAcao,
                                    ),
                                  ),
                                if (_mostrarComissao && _vendaBloqueada)
                                  Text(
                                    'Comissão Suspensa',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: corAcao,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setState(
                                    () => _mostrarComissao = !_mostrarComissao,
                                  ),
                                  child: Icon(
                                    _mostrarComissao
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.grey.shade600,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: _preparandoPedido
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: corAcao,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: Text(
                                    _vendaBloqueada
                                        ? 'VENDA BLOQUEADA'
                                        : 'REVISAR PEDIDO (GERAR PDF)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  onPressed: _vendaBloqueada
                                      ? null
                                      : _revisarPedido,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
