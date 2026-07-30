import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'form_pedido_venda.dart';

class TelaMeusPedidos extends StatefulWidget {
  const TelaMeusPedidos({super.key});

  @override
  State<TelaMeusPedidos> createState() => _TelaMeusPedidosState();
}

class _TelaMeusPedidosState extends State<TelaMeusPedidos> {
  String _statusFiltro = 'Todos';

  String _termoBuscaCliente = '';
  final TextEditingController _buscaCtrl = TextEditingController();
  DateTime? _dataInicial;
  DateTime? _dataFinal;

  pw.Font? _fonteNormal;
  pw.Font? _fonteNegrito;
  bool _carregandoFontes = true;

  String _nomeVendedorLogado = '';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _carregarFontesNaMemoria();
    _identificarVendedorLogado();
  }

  Future<void> _identificarVendedorLogado() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        final email = user.email!;

        if (email == 'admin@noeixo.com.br' ||
            email == 'diretoria@noeixo.com.br') {
          if (mounted) setState(() => _isAdmin = true);
          return;
        }

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
          } else if (data.containsKey('nome') && data['nome'] != null) {
            if (mounted) setState(() => _nomeVendedorLogado = data['nome']);
            return;
          }
        }

        final docUsuario = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(email)
            .get();

        if (docUsuario.exists && docUsuario.data() != null) {
          final data = docUsuario.data()!;
          if (data.containsKey('nome') && data['nome'] != null) {
            if (mounted) setState(() => _nomeVendedorLogado = data['nome']);
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao identificar vendedor logado: $e');
    }
  }

  Future<void> _carregarFontesNaMemoria() async {
    try {
      final fontDataNormal = await rootBundle.load(
        'assets/fonts/Roboto-Regular.ttf',
      );
      _fonteNormal = pw.Font.ttf(fontDataNormal);

      final fontDataBold = await rootBundle.load(
        'assets/fonts/Roboto-Bold.ttf',
      );
      _fonteNegrito = pw.Font.ttf(fontDataBold);
    } catch (e) {
      _fonteNormal = pw.Font.helvetica();
      _fonteNegrito = pw.Font.helveticaBold();
    }
    if (mounted) setState(() => _carregandoFontes = false);
  }

  String _formatarDataHora(Timestamp? timestamp) {
    if (timestamp == null) return 'Sincronizando...';
    DateTime data = timestamp.toDate();
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  String _formatarDataSimples(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Future<void> _selecionarData(bool isInicial) async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (escolhida != null && mounted) {
      setState(() {
        if (isInicial)
          _dataInicial = escolhida;
        else
          _dataFinal = escolhida;
      });
    }
  }

  // =========================================================================
  // ATUALIZAÇÃO: CORES E ÍCONES PARA O NOVO STATUS
  // =========================================================================
  Color _obterCorStatus(String status) {
    switch (status) {
      case 'Aberto':
        return Colors.blue.shade700;
      case 'Em Análise':
        return Colors.amber.shade700;
      case 'Devolvido':
      case 'Devolvido pelo Cliente':
        return Colors.red.shade700;
      case 'Aprovado':
        return Colors.teal;
      case 'Pendente Cliente':
        return Colors.orange;
      case 'Faturado':
        return Colors.green.shade700;
      case 'Cancelado':
        return Colors.grey.shade800;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _obterIconeStatus(String status) {
    switch (status) {
      case 'Aberto':
        return Icons.inbox;
      case 'Em Análise':
        return Icons.hourglass_top;
      case 'Devolvido':
        return Icons.warning_amber_rounded;
      case 'Devolvido pelo Cliente':
        return Icons.assignment_return;
      case 'Aprovado':
        return Icons.verified;
      case 'Pendente Cliente':
        return Icons.support_agent;
      case 'Faturado':
        return Icons.local_shipping;
      case 'Cancelado':
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  Future<void> _aprovarManualmente(String pedidoId) async {
    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Forçar Aprovação'),
            content: const Text(
              'O cliente autorizou o pedido verbalmente/pelo WhatsApp? Ao confirmar, o pedido entrará no fluxo comercial.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sim, Aprovar Pedido'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmar) {
      try {
        await FirebaseFirestore.instance
            .collection('pedidos_venda')
            .doc(pedidoId)
            .update({
              'status': 'Aberto',
              'status_comercial': 'Aberto',
              'dataAprovacaoVendedor': FieldValue.serverTimestamp(),
              'obsAprovacao': 'Aprovado manualmente pelo representante.',
            });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pedido aprovado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao aprovar: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  Future<Uint8List> _gerarPdf(Map<String, dynamic> dados) async {
    final pdf = pw.Document();
    final List itens = dados['itens'] ?? [];
    final corSucesso = PdfColors.green;
    final corAlerta = PdfColors.purple;
    final corTabela = PdfColors.teal;
    final corTextoTabela = PdfColors.white;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: _fonteNormal, bold: _fonteNegrito),
        ),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'NoEixo Têxtil',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text('Documento Auxiliar de Venda - Cópia'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Status: ${dados['status_comercial'] ?? dados['status'] ?? 'Aberto'}',
                      style: pw.TextStyle(
                        color:
                            (dados['status_comercial'] == 'Aberto' ||
                                dados['status'] == 'ABERTO')
                            ? corSucesso
                            : corAlerta,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),

            pw.Text(
              'DADOS DO CLIENTE E CONDIÇÕES',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Cliente: ${dados['clienteNome']}'),
                      pw.Text('Região: ${dados['regiao'] ?? '-'}'),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Tipo: ${dados['tipoVenda']}'),
                      pw.Text(
                        'Pgto: ${dados['formaPagamento']} (${dados['condicaoPagamento']})',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            pw.Text(
              'ITENS DO PEDIDO',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(4.5),
                4: const pw.FlexColumnWidth(0.8),
                5: const pw.FlexColumnWidth(1.5),
                6: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: corTabela),
                  children:
                      [
                        'Foto',
                        'Ref',
                        'Produto',
                        'Grade',
                        'Qtd',
                        'Unit.',
                        'Subtotal',
                      ].map((titulo) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text(
                            titulo,
                            style: pw.TextStyle(
                              color: corTextoTabela,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                ...itens.map((item) {
                  List grade = item['gradeDistribuicao'] ?? [];
                  Map<String, List<String>> gradeAgrupada = {};
                  for (var g in grade) {
                    String cor = (g['cor'] ?? 'Sem cor').toString();
                    String tam = (g['tamanho'] ?? '').toString();
                    String qtd = (g['quantidade'] ?? 0).toString();
                    if (!gradeAgrupada.containsKey(cor))
                      gradeAgrupada[cor] = [];
                    gradeAgrupada[cor]!.add('${qtd}x $tam');
                  }
                  List<String> linhasGrade = [];
                  gradeAgrupada.forEach(
                    (cor, listaTamanhos) =>
                        linhasGrade.add('$cor: ${listaTamanhos.join(', ')}'),
                  );
                  String gradeStrFinal = linhasGrade.join('\n');

                  pw.Widget widgetFoto = pw.Container(width: 35, height: 35);
                  if (item['fotoBase64'] != null &&
                      item['fotoBase64'].toString().isNotEmpty) {
                    try {
                      final imageBytes = base64Decode(item['fotoBase64']);
                      widgetFoto = pw.Image(
                        pw.MemoryImage(imageBytes),
                        width: 35,
                        height: 35,
                        fit: pw.BoxFit.cover,
                      );
                    } catch (e) {
                      /* Silencioso */
                    }
                  }

                  return pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        alignment: pw.Alignment.center,
                        child: widgetFoto,
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          item['referencia']?.toString() ?? '-',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          item['nome']?.toString() ?? '-',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          gradeStrFinal,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          item['quantidadeTotal']?.toString() ?? '0',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'R\$ ${(item['precoVendido'] ?? 0).toDouble().toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'R\$ ${(item['valorTotal'] ?? 0).toDouble().toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if ((dados['descontoRealAplicadoPerc'] ?? 0) > 0)
                    pw.Text(
                      'Desconto Negociado: ${(dados['descontoRealAplicadoPerc'] ?? 0).toDouble().toStringAsFixed(1)}%',
                      style: const pw.TextStyle(color: PdfColors.orange800),
                    ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'TOTAL DO PEDIDO: R\$ ${(dados['valorFinalCobrado'] ?? 0).toDouble().toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  void _abrirVisualizadorPDF(Map<String, dynamic> dadosPedido) async {
    if (_carregandoFontes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aguarde, carregando motor de PDF...')),
      );
      return;
    }
    final bytes = await _gerarPdf(dadosPedido);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Pedido_Copia_${dadosPedido['clienteNome']}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    Query queryPedidos = FirebaseFirestore.instance
        .collection('pedidos_venda')
        .orderBy('dataPedido', descending: true);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Meus Pedidos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              children: [
                TextField(
                  controller: _buscaCtrl,
                  decoration: InputDecoration(
                    labelText: 'Buscar Cliente',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (val) =>
                      setState(() => _termoBuscaCliente = val.toLowerCase()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selecionarData(true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'De',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(
                            _dataInicial == null
                                ? 'Data Inicial'
                                : _formatarDataSimples(_dataInicial!),
                            style: TextStyle(
                              color: _dataInicial == null
                                  ? Colors.grey
                                  : Colors.black,
                              fontSize: 13,
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
                            labelText: 'Até',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(
                            _dataFinal == null
                                ? 'Data Final'
                                : _formatarDataSimples(_dataFinal!),
                            style: TextStyle(
                              color: _dataFinal == null
                                  ? Colors.grey
                                  : Colors.black,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_dataInicial != null || _dataFinal != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () => setState(() {
                          _dataInicial = null;
                          _dataFinal = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        [
                          'Todos',
                          'Pendente Cliente',
                          'Aberto',
                          'Em Análise',
                          'Devolvido',
                          'Aprovado',
                        ].map((status) {
                          bool selecionado = _statusFiltro == status;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                status,
                                style: TextStyle(
                                  color: selecionado
                                      ? Colors.white
                                      : Colors.blueGrey,
                                  fontWeight: selecionado
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: selecionado,
                              selectedColor: _obterCorStatus(status),
                              backgroundColor: Colors.grey.shade200,
                              onSelected: (bool valor) =>
                                  setState(() => _statusFiltro = status),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: queryPedidos.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Erro ao carregar os pedidos. Verifique a conexão.',
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                var documentos = snapshot.data!.docs;

                var listaFiltrada = documentos.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;

                  if (!_isAdmin && _nomeVendedorLogado.isNotEmpty) {
                    String vendedorDoPedido = data['representanteNome'] ?? '';
                    if (vendedorDoPedido != _nomeVendedorLogado) return false;
                  }

                  String statusCru =
                      data['status_comercial'] ?? data['status'] ?? 'Aberto';
                  String statusMapeado = statusCru;
                  if (statusCru == 'SOB ANÁLISE (DIRETORIA)')
                    statusMapeado = 'Em Análise';
                  if (statusCru == 'AGUARDANDO APROVAÇÃO DO CLIENTE')
                    statusMapeado = 'Pendente Cliente';
                  if (statusCru == 'ABERTO') statusMapeado = 'Aberto';

                  // ==============================================================
                  // MAPEAR PARA O FILTRO 'Devolvido' ABRANGER O CLIENTE
                  // ==============================================================
                  if (statusCru == 'Devolvido pelo Cliente')
                    statusMapeado = 'Devolvido';

                  if (_statusFiltro != 'Todos' &&
                      statusMapeado != _statusFiltro)
                    return false;

                  var clienteNome = (data['clienteNome'] ?? '')
                      .toString()
                      .toLowerCase();
                  if (_termoBuscaCliente.isNotEmpty &&
                      !clienteNome.contains(_termoBuscaCliente))
                    return false;

                  Timestamp? ts = data['dataPedido'] as Timestamp?;
                  DateTime? dataPedido = ts?.toDate();
                  if (dataPedido != null) {
                    if (_dataInicial != null &&
                        dataPedido.isBefore(_dataInicial!))
                      return false;
                    if (_dataFinal != null &&
                        dataPedido.isAfter(
                          _dataFinal!.add(const Duration(days: 1)),
                        ))
                      return false;
                  }

                  return true;
                }).toList();

                if (listaFiltrada.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhum pedido atende aos filtros.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: listaFiltrada.length,
                  itemBuilder: (context, index) {
                    final doc = listaFiltrada[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final String cliente =
                        data['clienteNome'] ?? 'Cliente não informado';
                    final String tipoVenda = data['tipoVenda'] ?? '-';
                    final double valorFinal = (data['valorFinalCobrado'] ?? 0)
                        .toDouble();
                    final Timestamp? dataPedidoTs =
                        data['dataPedido'] as Timestamp?;
                    final int totalItens =
                        (data['itens'] as List?)?.length ?? 0;

                    String statusExibicao =
                        data['status_comercial'] ?? data['status'] ?? 'Aberto';
                    if (statusExibicao == 'SOB ANÁLISE (DIRETORIA)')
                      statusExibicao = 'Em Análise';
                    if (statusExibicao == 'AGUARDANDO APROVAÇÃO DO CLIENTE')
                      statusExibicao = 'Pendente Cliente';
                    if (statusExibicao == 'ABERTO') statusExibicao = 'Aberto';

                    Color corStatus = _obterCorStatus(statusExibicao);

                    // =========================================================
                    // ATUALIZAÇÃO: PERMITE PUXAR MENSAGEM DO CLIENTE TAMBÉM
                    // =========================================================
                    String msgDevolucao = '';
                    if (statusExibicao == 'Devolvido' ||
                        statusExibicao == 'Devolvido pelo Cliente') {
                      List historico = data['historico_mensagens'] ?? [];
                      if (historico.isNotEmpty) {
                        msgDevolucao =
                            historico.last['mensagem'] ??
                            'Devolvido sem justificativa em texto.';
                      }
                    }

                    return Card(
                      elevation:
                          (statusExibicao == 'Devolvido' ||
                              statusExibicao == 'Devolvido pelo Cliente')
                          ? 4
                          : 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: corStatus.withOpacity(0.5),
                          width:
                              (statusExibicao == 'Devolvido' ||
                                  statusExibicao == 'Devolvido pelo Cliente')
                              ? 2
                              : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            color: corStatus.withOpacity(0.15),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        _obterIconeStatus(statusExibicao),
                                        color: corStatus,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          statusExibicao.toUpperCase(),
                                          style: TextStyle(
                                            color: corStatus,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatarDataHora(dataPedidoTs),
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cliente,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Modalidade: $tipoVenda',
                                        style: const TextStyle(
                                          color: Colors.blueGrey,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Volumes: $totalItens referência(s)',
                                        style: const TextStyle(
                                          color: Colors.blueGrey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Valor Total',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      'R\$ ${valorFinal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // =========================================================
                          // TARJA VERMELHA QUE MOSTRA A MENSAGEM
                          // =========================================================
                          if ((statusExibicao == 'Devolvido' ||
                                  statusExibicao == 'Devolvido pelo Cliente') &&
                              msgDevolucao.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.red.shade50,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.feedback,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          statusExibicao ==
                                                  'Devolvido pelo Cliente'
                                              ? 'Instrução do Cliente:'
                                              : 'Instrução de Correção (Gestor):',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          msgDevolucao,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const Divider(height: 1),

                          Container(
                            color: Colors.grey.shade50,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.blueGrey,
                                  ),
                                  label: const Text(
                                    'Ver PDF',
                                    style: TextStyle(
                                      color: Colors.blueGrey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () => _abrirVisualizadorPDF(data),
                                ),

                                if (statusExibicao == 'Pendente Cliente') ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: const Icon(Icons.thumb_up, size: 16),
                                    label: const Text(
                                      'Aprovar Manual',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _aprovarManualmente(doc.id),
                                  ),
                                ],

                                // =========================================================
                                // BOTÃO AJUSTAR PEDIDO: LIBERADO PARA O CLIENTE TAMBÉM
                                // =========================================================
                                if (statusExibicao == 'Devolvido' ||
                                    statusExibicao ==
                                        'Devolvido pelo Cliente') ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade800,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text(
                                      'Ajustar Pedido',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FormPedidoVenda(
                                            empresaId:
                                                data['empresa_id'] ??
                                                'teste_textil',
                                            clienteId:
                                                data['clienteId'] ??
                                                'ID_NAO_ENCONTRADO',
                                            clienteNome: cliente,
                                            regiao:
                                                data['regiao'] ??
                                                'Não Informada',
                                            whatsappCliente:
                                                data['whatsapp'] ?? '',
                                            pedidoEdicaoId: doc.id,
                                            dadosEdicao: data,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
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
}
