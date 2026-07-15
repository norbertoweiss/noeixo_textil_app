import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../comercial/tela_catalogo_vendas.dart';
import 'tela_preview_pedido_pdf.dart';

class FormPedidoVenda extends StatefulWidget {
  final String empresaId;
  final String clienteId;
  final String clienteNome;
  final String regiao;
  final String whatsappCliente; // <-- NOVO: Recebe direto da Carteira

  const FormPedidoVenda({
    super.key,
    required this.empresaId,
    required this.clienteId,
    required this.clienteNome,
    required this.regiao,
    this.whatsappCliente = '', // <-- NOVO
  });

  @override
  State<FormPedidoVenda> createState() => _FormPedidoVendaState();
}

class _FormPedidoVendaState extends State<FormPedidoVenda> {
  final bool _isAdmin = true;

  String _tipoVenda = 'PRONTA ENTREGA';
  List<Map<String, dynamic>> _carrinhoItens = [];

  bool _preparandoPedido = false;

  final TextEditingController _descontoExtraCtrl = TextEditingController(
    text: '0.0',
  );
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

  @override
  void initState() {
    super.initState();
    _carregarDadosFinanceiros();
  }

  @override
  void dispose() {
    _cronometro?.cancel();
    _descontoExtraCtrl.dispose();
    super.dispose();
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
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (escolhida != null && mounted) {
      setState(() => _dataPrevistaEntrega = escolhida);
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
    final itemSelecionado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaCatalogoVendas(empresaId: widget.empresaId),
      ),
    );

    if (itemSelecionado != null && itemSelecionado is Map<String, dynamic>) {
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
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Offline. Reserva será feita depois.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      _iniciarCronometro();
      setState(() => _carrinhoItens.add(itemSelecionado));
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

  double get _comissaoPerc {
    double desc = _descontoRealTotalPerc;
    if (desc <= 10.01) return 10.0;
    if (desc <= 15.01) return 8.0;
    if (desc <= 20.01) return 6.0;
    if (desc <= 25.01) return 5.0;
    return 0.0;
  }

  Color _getCorTermometro() {
    double desc = _descontoRealTotalPerc;
    if (desc <= 0.01) return Colors.blueGrey;
    if (desc <= 10.01) return Colors.blue.shade600;
    if (desc <= 15.01) return Colors.amber.shade600;
    if (desc <= 20.01) return Colors.orange.shade600;
    if (desc <= 25.01) return Colors.red.shade600;
    return Colors.deepPurple;
  }

  void _revisarPedido() {
    if (_carrinhoItens.isEmpty) return;

    if (_formaPagamentoSelecionada == null ||
        _condicaoPagamentoSelecionada == null ||
        _dataPrevistaEntrega == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Preencha a Data de Entrega e as Condições Financeiras antes de revisar o pedido!',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _preparandoPedido = true);

    Map<String, dynamic> pacoteParaPDF = {
      'empresa_id': widget.empresaId,
      'clienteId': widget.clienteId,
      'clienteNome': widget.clienteNome,
      'regiao': widget.regiao,
      'whatsapp': widget.whatsappCliente, // <-- PEGA DIRETO DA TELA ANTERIOR
      'tipoVenda': _tipoVenda,
      'formaPagamento': _formaPagamentoSelecionada,
      'condicaoPagamento': _condicaoPagamentoSelecionada,
      'dataEntregaPrevista': _dataPrevistaEntrega,
      'dataEntregaStr': _formatarData(_dataPrevistaEntrega!),
      'valorTotalTabela': _valorTotalTabelaPura,
      'valorFinalCobrado': _valorFinalComDescontoExtra,
      'descontoRealAplicadoPerc': _descontoRealTotalPerc,
      'comissaoPrevistaPerc': _comissaoPerc,
      'comissaoPrevistaValor':
          _valorFinalComDescontoExtra * (_comissaoPerc / 100),
      'itens': _carrinhoItens,
      'statusPrevisto': _descontoRealTotalPerc > 25.01
          ? 'SOB ANÁLISE (DIRETORIA)'
          : 'ABERTO',
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
    Color corAcao = _getCorTermometro();
    bool bloqueioDiretoria = _descontoRealTotalPerc > 25.01;

    return Scaffold(
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
                              if (val)
                                setState(() => _tipoVenda = 'PRONTA ENTREGA');
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
                : ListView.builder(
                    itemCount: _carrinhoItens.length,
                    itemBuilder: (context, index) {
                      final item = _carrinhoItens[index];
                      double totalItemTabela =
                          item['quantidadeTotal'] * item['precoTabela'];
                      double totalItemVendido =
                          item['quantidadeTotal'] * item['precoVendido'];
                      bool temDescontoNaPeca =
                          item['precoVendido'] < item['precoTabela'];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: (item['fotoBase64'] != null)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
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
                            'Qtd: ${item['quantidadeTotal']} pçs',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (temDescontoNaPeca)
                                    Text(
                                      'R\$ ${totalItemTabela.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                        decoration: TextDecoration.lineThrough,
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
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _formaPagamentoSelecionada = val),
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
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(
                            () => _condicaoPagamentoSelecionada = val,
                          ),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _dataPrevistaEntrega == null
                                ? 'Selecionar Data...'
                                : _formatarData(_dataPrevistaEntrega!),
                            style: TextStyle(
                              color: _dataPrevistaEntrega == null
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
                ],
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
                              onChanged: (val) => setState(
                                () => _descontoExtraPerc =
                                    double.tryParse(val.replaceAll(',', '.')) ??
                                    0.0,
                              ),
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
                                bloqueioDiretoria
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
                              if (_mostrarComissao && !bloqueioDiretoria)
                                Text(
                                  'Comissão: ${_comissaoPerc}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: corAcao,
                                  ),
                                ),
                              if (_mostrarComissao && bloqueioDiretoria)
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
                                label: const Text(
                                  'REVISAR PEDIDO (GERAR PDF)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                onPressed: _revisarPedido,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
