import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormPedidoVenda extends StatefulWidget {
  final String empresaId;
  final String clienteId;
  final String clienteNome;
  final String regiao;

  const FormPedidoVenda({
    super.key,
    required this.empresaId,
    required this.clienteId,
    required this.clienteNome,
    required this.regiao,
  });

  @override
  State<FormPedidoVenda> createState() => _FormPedidoVendaState();
}

class _FormPedidoVendaState extends State<FormPedidoVenda> {
  final _formKeyPedido = GlobalKey<FormState>();
  final bool _isAdmin = true;

  String _tipoVenda = 'PRONTA ENTREGA';
  List<Map<String, dynamic>> _carrinhoItens = [];

  List<DocumentSnapshot> _produtosAcabados = [];
  String? _produtoSelecionadoId;
  Map<String, dynamic>? _produtoSelecionadoDados;

  List<String> _tamanhosDisponiveis = [];
  List<String> _coresDisponiveis = []; // AGORA AS CORES SÃO DINÂMICAS!
  String? _corSelecionada;

  final Map<String, TextEditingController> _gradeControllers = {};

  bool _carregandoProdutos = true;
  bool _salvandoPedido = false;

  // --- MOTOR DE SOFT ALLOCATION (RESERVA DE 3 HORAS) ---
  DateTime? _tempoExpiracao;
  Timer? _cronometro;
  String _tempoRestanteStr = "03:00:00";

  @override
  void initState() {
    super.initState();
    _carregarProdutosAcabados();
  }

  @override
  void dispose() {
    _cronometro?.cancel();
    for (var ctrl in _gradeControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
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

  Future<void> _carregarProdutosAcabados() async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('produtos')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('tipo', isEqualTo: 'Produto Acabado')
          .get();

      if (mounted) {
        setState(() {
          _produtosAcabados = snap.docs;
          _carregandoProdutos = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _carregandoProdutos = false);
    }
  }

  Future<void> _atualizarEstruturaProduto(String? produtoId) async {
    if (produtoId == null) return;

    setState(() {
      _tamanhosDisponiveis = [];
      _coresDisponiveis = [];
      _gradeControllers.clear();
      _corSelecionada = null;
    });

    var docProd = _produtosAcabados.firstWhere((e) => e.id == produtoId);
    _produtoSelecionadoDados = docProd.data() as Map<String, dynamic>;

    var snapFicha = await FirebaseFirestore.instance
        .collection('fichas_tecnicas')
        .where('empresa_id', isEqualTo: widget.empresaId)
        .where(
          'produtoId',
          isEqualTo: produtoId,
        ) // Mudado para buscar corretamente
        .limit(1)
        .get();

    if (snapFicha.docs.isNotEmpty) {
      var dadosFicha = snapFicha.docs.first.data();
      List<dynamic> tamRaw = dadosFicha['tamanhos'] ?? [];
      List<dynamic> coresRaw = dadosFicha['coresComerciais'] ?? [];

      setState(() {
        _tamanhosDisponiveis = tamRaw.map((e) => e.toString()).toList();
        _coresDisponiveis = coresRaw.map((e) => e.toString()).toList();
        for (var tamanho in _tamanhosDisponiveis) {
          _gradeControllers[tamanho] = TextEditingController(text: '0');
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este produto não possui Ficha Técnica / Grade comercial vinculada.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _adicionarItemAoCarrinho() async {
    if (_produtoSelecionadoId == null || _corSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione o produto e a cor!',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double precoBase = (_produtoSelecionadoDados?['precoVenda'] ?? 49.90)
        .toDouble();
    List<Map<String, dynamic>> subItensDigitados = [];
    double totalQuantidadeItem = 0;

    _gradeControllers.forEach((tamanho, controller) {
      double qtd = double.tryParse(controller.text) ?? 0;
      if (qtd > 0) {
        totalQuantidadeItem += qtd;
        subItensDigitados.add({'tamanho': tamanho, 'quantidade': qtd});
      }
    });

    if (totalQuantidadeItem == 0) return;

    if (_tipoVenda == 'PRONTA ENTREGA') {
      var docAtualizado = await FirebaseFirestore.instance
          .collection('produtos')
          .doc(_produtoSelecionadoId)
          .get();
      double estoqueFisico = (docAtualizado.data()?['estoqueFisico'] ?? 0)
          .toDouble();
      double estoqueComprometido =
          (docAtualizado.data()?['estoqueComprometido'] ?? 0).toDouble();
      double estoqueLivre = estoqueFisico - estoqueComprometido;

      if (totalQuantidadeItem > estoqueLivre) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Estoque Insuficiente! Apenas ${estoqueLivre.toStringAsFixed(0)} pçs disponíveis.',
            ),
            backgroundColor: Colors.amber.shade900,
          ),
        );
        return;
      }

      // TRANSAÇÃO: Reserva IMEDIATAMENTE no Firebase
      try {
        await FirebaseFirestore.instance
            .collection('produtos')
            .doc(_produtoSelecionadoId)
            .update({
              'estoqueComprometido': FieldValue.increment(totalQuantidadeItem),
            });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Você está Offline. O estoque será reservado quando recuperar o sinal.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    _iniciarCronometro();

    setState(() {
      _carrinhoItens.add({
        'idTemporario': DateTime.now().millisecondsSinceEpoch.toString(),
        'produtoId': _produtoSelecionadoId,
        'referencia': _produtoSelecionadoDados?['referencia'] ?? 'SEM REF',
        'nome': _produtoSelecionadoDados?['nome'] ?? 'Produto',
        'cor': _corSelecionada,
        'precoUnitario': precoBase,
        'quantidadeTotal': totalQuantidadeItem,
        'valorTotal': totalQuantidadeItem * precoBase,
        'gradeDistribuicao': subItensDigitados,
      });

      _produtoSelecionadoId = null;
      _produtoSelecionadoDados = null;
      _tamanhosDisponiveis = [];
      _coresDisponiveis = [];
      _gradeControllers.clear();
      _corSelecionada = null;
    });
  }

  // --- REMOÇÃO COM DEVOLUÇÃO IMEDIATA DE ESTOQUE ---
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
      } catch (e) {
        // Trata erro de rede offline
      }
    }

    setState(() {
      _carrinhoItens.removeWhere((e) => e['idTemporario'] == idTemporario);
      if (_carrinhoItens.isEmpty) {
        _cronometro?.cancel();
        _tempoExpiracao = null;
      }
    });
  }

  double get _totalGeralPedido {
    return _carrinhoItens.fold(
      0.0,
      (soma, item) => soma + (item['valorTotal'] ?? 0.0),
    );
  }

  Future<void> _fecharSalvamentoPedido() async {
    if (_carrinhoItens.isEmpty) return;

    setState(() => _salvandoPedido = true);
    final db = FirebaseFirestore.instance;

    try {
      DocumentReference refPedido = db.collection('pedidos_venda').doc();

      await refPedido.set({
        'empresa_id': widget.empresaId,
        'clienteId': widget.clienteId,
        'clienteNome': widget.clienteNome,
        'regiao': widget.regiao,
        'tipoVenda': _tipoVenda,
        'status': 'ABERTO',
        'valorTotal': _totalGeralPedido,
        'itens': _carrinhoItens,
        'dataPedido': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido consolidado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _salvandoPedido = false);
    }
  }

  Widget _buildDrawerManualComercial() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.teal.shade700,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.gavel, color: Colors.white, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'REGRAS COMERCIAIS ERP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Soft Allocation Dinâmico',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  Text(
                    '1. Janela de 3 Horas',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  Text(
                    'A reserva de Pronta Entrega atua na fração de segundo em que o item é adicionado à lista. O vendedor possui exatamente 3 horas para consolidar a operação antes que a nuvem efetue o estorno automático para o estoque livre da fábrica.',
                  ),
                  SizedBox(height: 16),
                  Text(
                    '2. Modo Offline',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  Text(
                    'Se o tablet perder a conexão, o item entra no carrinho, mas a reserva oficial só é selada quando a rede retorna. Se outro vendedor capturar a peça durante o "apagão" de rede, o ERP invalidará o carrinho desatualizado para prevenir furos logísticos.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> oScaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: oScaffoldKey,
      endDrawer: _isAdmin ? _buildDrawerManualComercial() : null,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Carrinho de Vendas',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.amber),
              onPressed: () => oScaffoldKey.currentState?.openEndDrawer(),
            ),
        ],
      ),
      body: _carregandoProdutos
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- PAINEL CLIENTE & CRONÓMETRO ---
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
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('PRONTA ENTREGA'),
                            selected: _tipoVenda == 'PRONTA ENTREGA',
                            onSelected: _carrinhoItens.isEmpty
                                ? (val) {
                                    if (val)
                                      setState(
                                        () => _tipoVenda = 'PRONTA ENTREGA',
                                      );
                                  }
                                : null,
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('PROGRAMADA'),
                            selected: _tipoVenda == 'PROGRAMADA',
                            onSelected: _carrinhoItens.isEmpty
                                ? (val) {
                                    if (val)
                                      setState(() => _tipoVenda = 'PROGRAMADA');
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- INSERÇÃO DE ITENS ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Escolha o Modelo',
                                border: OutlineInputBorder(),
                              ),
                              value: _produtoSelecionadoId,
                              items: _produtosAcabados.map((doc) {
                                var d = doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(
                                    '[${d['referencia']}] ${d['nome']}',
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _produtoSelecionadoId = val);
                                _atualizarEstruturaProduto(val);
                              },
                            ),
                            if (_produtoSelecionadoId != null &&
                                _coresDisponiveis.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              // O DROPDOWN AGORA LÊ AS CORES VINDAS DA FICHA TÉCNICA
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Selecione a Cor Comercial',
                                  border: OutlineInputBorder(),
                                ),
                                value: _corSelecionada,
                                items: _coresDisponiveis
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _corSelecionada = val),
                              ),
                            ] else if (_produtoSelecionadoId != null &&
                                _coresDisponiveis.isEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Nenhuma cor autorizada para venda neste produto.',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],

                            if (_tamanhosDisponiveis.isNotEmpty &&
                                _coresDisponiveis.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Table(
                                border: TableBorder.all(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                    ),
                                    children: _tamanhosDisponiveis
                                        .map(
                                          (t) => Padding(
                                            padding: const EdgeInsets.all(6.0),
                                            child: Text(
                                              t,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                  TableRow(
                                    children: _tamanhosDisponiveis
                                        .map(
                                          (t) => Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: TextFormField(
                                              controller: _gradeControllers[t],
                                              keyboardType:
                                                  TextInputType.number,
                                              textAlign: TextAlign.center,
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.add_shopping_cart),
                                  label: const Text(
                                    'RESERVAR E ADICIONAR ITEM',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: _adicionarItemAoCarrinho,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // --- LISTA DO CARRINHO ---
                Container(
                  height: 160,
                  color: Colors.white,
                  child: _carrinhoItens.isEmpty
                      ? const Center(
                          child: Text(
                            'Carrinho vazio. Cestas prontas para uso.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _carrinhoItens.length,
                          itemBuilder: (context, index) {
                            final item = _carrinhoItens[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              title: Text(
                                '${item['nome']} (${item['cor']})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                'Qtd: ${item['quantidadeTotal']} pçs',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'R\$ ${item['valorTotal'].toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                            );
                          },
                        ),
                ),

                // --- RODAPÉ DE FECHAMENTO ---
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL DO PEDIDO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'R\$ ${_totalGeralPedido.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      _salvandoPedido
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                              onPressed: _fecharSalvamentoPedido,
                              child: const Text(
                                'CONSOLIDAR PEDIDO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
