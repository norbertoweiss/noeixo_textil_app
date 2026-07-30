import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/pedido_service.dart';

class TelaPreviewPedidoPDF extends StatefulWidget {
  final Map<String, dynamic> dadosPedido;

  const TelaPreviewPedidoPDF({super.key, required this.dadosPedido});

  @override
  State<TelaPreviewPedidoPDF> createState() => _TelaPreviewPedidoPDFState();
}

class _TelaPreviewPedidoPDFState extends State<TelaPreviewPedidoPDF> {
  bool _salvando = false;

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
      debugPrint('Erro crítico ao ler a fonte local: $e');
      _fonteNormal = pw.Font.helvetica();
      _fonteNegrito = pw.Font.helveticaBold();
    }

    if (mounted) setState(() => _carregandoFontes = false);
  }

  Future<Uint8List> _gerarPdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    final dados = widget.dadosPedido;
    final List itens = dados['itens'] ?? [];

    final corSucesso = PdfColors.green;
    final corAlerta = PdfColors.purple;
    final corTabela = PdfColors.teal;
    final corTextoTabela = PdfColors.white;

    // ========================================================
    // PREPARANDO AS VARIÁVEIS DE OBSERVAÇÃO
    // ========================================================
    final String observacoesVendedor = dados['observacoes']?.toString() ?? '';
    final List historico = dados['historico_mensagens'] ?? [];

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
                    pw.Text('Documento Auxiliar de Venda - Conferência'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Data: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                    ),
                    pw.Text(
                      'Status: ${dados['statusPrevisto']}',
                      style: pw.TextStyle(
                        color: dados['statusPrevisto'] == 'ABERTO'
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
                      pw.Text('Entrega Prevista: ${dados['dataEntregaStr']}'),
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
                      debugPrint('Erro ao carregar imagem no PDF: $e');
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
                  pw.Text(
                    'Total Base (Tabela): R\$ ${(dados['valorTotalTabela'] ?? 0).toDouble().toStringAsFixed(2)}',
                    style: const pw.TextStyle(color: PdfColors.grey600),
                  ),
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

            pw.SizedBox(height: 20),

            // ========================================================
            // NOVO: CAIXA PROFISSIONAL DE HISTÓRICO NO PDF
            // ========================================================
            if (historico.isNotEmpty || observacoesVendedor.isNotEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HISTÓRICO E OBSERVAÇÕES',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    ...historico.map((h) {
                      String autor = h['autor'] == 'CLIENTE'
                          ? 'Cliente'
                          : 'Gestor/Vendedor';
                      String msg = h['mensagem'] ?? '';
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          '$autor: $msg',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      );
                    }).toList(),
                    if (observacoesVendedor.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(
                          'Vendedor: $observacoesVendedor',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Text(
                '_________________________________________________\nAssinatura / De Acordo do Cliente',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(color: PdfColors.grey600),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _abrirWhatsAppComLink(
    String idPedido,
    String tokenAprovacao,
    Map<String, dynamic> dados,
  ) async {
    String linkAprovacao =
        "https://noeixo-textil.web.app/#/aprovar?id=$idPedido&token=$tokenAprovacao";
    String nomeCliente = dados['clienteNome'] ?? 'Cliente';

    String telefoneBruto = dados['whatsapp']?.toString() ?? '';
    String telefoneLimpo = telefoneBruto.replaceAll(RegExp(r'[^0-9]'), '');

    if (telefoneLimpo.length == 10 || telefoneLimpo.length == 11) {
      telefoneLimpo = '55$telefoneLimpo';
    }

    String mensagem =
        "Olá, $nomeCliente!\n\n"
        "A *World Baby Kids* Agradece o seu pedido.\n"
        "Clique no link seguro abaixo para conferir as quantidades e autorizar o envio para a fábrica:\n"
        "👉 $linkAprovacao\n\n"
        "Qualquer dúvida, estou à disposição!";

    String urlWhatsApp;
    if (telefoneLimpo.isNotEmpty) {
      urlWhatsApp =
          "https://api.whatsapp.com/send?phone=$telefoneLimpo&text=${Uri.encodeComponent(mensagem)}";
    } else {
      urlWhatsApp =
          "https://api.whatsapp.com/send?text=${Uri.encodeComponent(mensagem)}";
    }

    try {
      if (await canLaunchUrl(Uri.parse(urlWhatsApp))) {
        await launchUrl(
          Uri.parse(urlWhatsApp),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível abrir o WhatsApp no seu dispositivo.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao abrir WhatsApp: $e');
    }
  }

  Future<void> _salvarPedidoOficial() async {
    setState(() => _salvando = true);

    final dados = Map<String, dynamic>.from(widget.dadosPedido);

    try {
      String tokenAprovacao = DateTime.now().millisecondsSinceEpoch.toString();

      dados['status'] = (dados['descontoRealAplicadoPerc'] ?? 0) > 25.01
          ? 'SOB ANÁLISE (DIRETORIA)'
          : 'AGUARDANDO APROVAÇÃO DO CLIENTE';

      final pedidoService = PedidoService();
      String pedidoId = await pedidoService.salvarPedidoOficial(
        dadosPedido: dados,
        tokenAprovacao: tokenAprovacao,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dados['status'] == 'SOB ANÁLISE (DIRETORIA)'
                  ? 'Pedido travado. Enviado para a Diretoria.'
                  : 'Pedido salvo! Abrindo o WhatsApp...',
            ),
            backgroundColor: dados['status'] == 'SOB ANÁLISE (DIRETORIA)'
                ? Colors.deepPurple
                : Colors.teal,
          ),
        );

        if (dados['status'] == 'AGUARDANDO APROVAÇÃO DO CLIENTE') {
          await _abrirWhatsAppComLink(pedidoId, tokenAprovacao, dados);
        }

        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar o pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _forcarDownloadPDF() async {
    try {
      final bytes = await _gerarPdf(PdfPageFormat.a4);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Pedido_${widget.dadosPedido['clienteNome']}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao gerar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool exigeAprovacao = widget.dadosPedido['statusPrevisto'] != 'ABERTO';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar e Partilhar PDF'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, size: 28),
            tooltip: 'Forçar Download do PDF',
            onPressed: _carregandoFontes ? null : _forcarDownloadPDF,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _carregandoFontes
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Montando o documento...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : PdfPreview(
              build: (format) => _gerarPdf(format),
              allowSharing: true,
              allowPrinting: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              pdfFileName: 'Pedido_${widget.dadosPedido['clienteNome']}.pdf',
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: _salvando
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: exigeAprovacao
                      ? Colors.deepPurple
                      : Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: Icon(exigeAprovacao ? Icons.gavel : Icons.send),
                label: Text(
                  exigeAprovacao
                      ? 'ENVIAR PARA APROVAÇÃO DA DIRETORIA'
                      : 'SALVAR E ENVIAR LINK POR WHATSAPP',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onPressed: _salvarPedidoOficial,
              ),
      ),
    );
  }
}
