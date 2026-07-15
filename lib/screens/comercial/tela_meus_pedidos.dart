import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TelaMeusPedidos extends StatefulWidget {
  const TelaMeusPedidos({super.key});

  @override
  State<TelaMeusPedidos> createState() => _TelaMeusPedidosState();
}

class _TelaMeusPedidosState extends State<TelaMeusPedidos> {
  String _statusFiltro = 'Todos';

  // Variáveis para os novos filtros
  String _termoBuscaCliente = '';
  final TextEditingController _buscaCtrl = TextEditingController();
  DateTime? _dataInicial;
  DateTime? _dataFinal;

  // Variáveis para o motor de PDF
  pw.Font? _fonteNormal;
  pw.Font? _fonteNegrito;
  bool _carregandoFontes = true;

  @override
  void initState() {
    super.initState();
    _carregarFontesNaMemoria();
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

  Color _obterCorStatus(String status) {
    if (status.contains('ABERTO')) return Colors.green;
    if (status.contains('ANÁLISE')) return Colors.deepPurple;
    if (status.contains('FATURADO')) return Colors.blue;
    if (status.contains('CANCELADO')) return Colors.red;
    return Colors.grey;
  }

  IconData _obterIconeStatus(String status) {
    if (status.contains('ABERTO')) return Icons.check_circle_outline;
    if (status.contains('ANÁLISE')) return Icons.gavel;
    if (status.contains('FATURADO')) return Icons.local_shipping;
    if (status.contains('CANCELADO')) return Icons.cancel;
    return Icons.info_outline;
  }

  // =========================================================================
  // APROVAÇÃO MANUAL DO VENDEDOR (DESTRAVA O PEDIDO)
  // =========================================================================
  Future<void> _aprovarManualmente(String pedidoId) async {
    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Forçar Aprovação'),
            content: const Text(
              'O cliente autorizou o pedido verbalmente/pelo WhatsApp? Ao confirmar, o pedido descerá para a fábrica.',
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
              'status': 'ABERTO',
              'dataAprovacaoVendedor': FieldValue.serverTimestamp(),
              'obsAprovacao': 'Aprovado manualmente pelo representante.',
            });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pedido aprovado e enviado para produção!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao aprovar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // =========================================================================
  // GERAÇÃO DE PDF PARA VISUALIZAÇÃO DIRETA
  // =========================================================================
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
                      'Status: ${dados['status']}',
                      style: pw.TextStyle(
                        color: dados['status'] == 'ABERTO'
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
                      final memoryImage = pw.MemoryImage(imageBytes);
                      widgetFoto = pw.Image(
                        memoryImage,
                        width: 35,
                        height: 35,
                        fit: pw.BoxFit.cover,
                      );
                    } catch (e) {
                      // Silencioso se falhar
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
          // ========================================================
          // PAINEL DE FILTROS SUPERIOR (NOVO)
          // ========================================================
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              children: [
                // Busca por nome
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

                // Filtro de Data
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

                // Filtro de Status
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        [
                          'Todos',
                          'AGUARDANDO APROVAÇÃO DO CLIENTE',
                          'ABERTO',
                          'SOB ANÁLISE (DIRETORIA)',
                          'FATURADO',
                        ].map((status) {
                          bool selecionado = _statusFiltro == status;
                          String labelDisplay = status;
                          if (status == 'SOB ANÁLISE (DIRETORIA)')
                            labelDisplay = 'Em Análise';
                          if (status == 'AGUARDANDO APROVAÇÃO DO CLIENTE')
                            labelDisplay = 'Pendente Cliente';

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                labelDisplay,
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
                              selectedColor: Colors.indigo,
                              backgroundColor: Colors.grey.shade200,
                              onSelected: (bool valor) {
                                setState(() => _statusFiltro = status);
                              },
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // ========================================================
          // LISTA DE PEDIDOS EM TEMPO REAL
          // ========================================================
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pedidos_venda')
                  .orderBy('dataPedido', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Erro ao carregar os pedidos.'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var documentos = snapshot.data!.docs;

                // FILTRAGEM NA MEMÓRIA
                var listaFiltrada = documentos.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  var status = data['status'] ?? 'ABERTO';
                  var clienteNome = (data['clienteNome'] ?? '')
                      .toString()
                      .toLowerCase();

                  Timestamp? ts = data['dataPedido'] as Timestamp?;
                  DateTime? dataPedido = ts?.toDate();

                  // Filtro Status
                  if (_statusFiltro != 'Todos' && status != _statusFiltro)
                    return false;

                  // Filtro Texto
                  if (_termoBuscaCliente.isNotEmpty &&
                      !clienteNome.contains(_termoBuscaCliente))
                    return false;

                  // Filtro Data
                  if (dataPedido != null) {
                    if (_dataInicial != null &&
                        dataPedido.isBefore(_dataInicial!))
                      return false;
                    // Adiciona 1 dia na data final para incluir todo o dia selecionado até 23:59
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
                    final String status = data['status'] ?? 'ABERTO';
                    final String tipoVenda = data['tipoVenda'] ?? '-';
                    final double valorFinal = (data['valorFinalCobrado'] ?? 0)
                        .toDouble();
                    final Timestamp? dataPedidoTs =
                        data['dataPedido'] as Timestamp?;
                    final int totalItens =
                        (data['itens'] as List?)?.length ?? 0;

                    Color corStatus = _obterCorStatus(status);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: corStatus.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TOPO DO CARD
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            color: corStatus.withOpacity(0.1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        _obterIconeStatus(status),
                                        color: corStatus,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: corStatus,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
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
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // CORPO DO CARD
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

                          const Divider(height: 1),

                          // ========================================================
                          // AÇÕES DO CARTÃO (VISUALIZAR PDF E APROVAÇÃO MANUAL)
                          // ========================================================
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
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Ver PDF',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  onPressed: () => _abrirVisualizadorPDF(data),
                                ),
                                if (status ==
                                    'AGUARDANDO APROVAÇÃO DO CLIENTE') ...[
                                  const SizedBox(width: 12),
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
