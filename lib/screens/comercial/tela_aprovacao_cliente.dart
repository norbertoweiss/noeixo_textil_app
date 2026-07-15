import 'dart:typed_data';
import 'dart:convert'; // <-- Importação necessária
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TelaAprovacaoCliente extends StatefulWidget {
  final String pedidoId;
  final String token;

  const TelaAprovacaoCliente({
    super.key,
    required this.pedidoId,
    required this.token,
  });

  @override
  State<TelaAprovacaoCliente> createState() => _TelaAprovacaoClienteState();
}

class _TelaAprovacaoClienteState extends State<TelaAprovacaoCliente> {
  bool _carregando = true;
  bool _confirmado = false;
  String _mensagemErro = '';
  Map<String, dynamic>? _dadosPedido;

  pw.Font? _fonteNormal;
  pw.Font? _fonteNegrito;

  @override
  void initState() {
    super.initState();
    _carregarFontesNaMemoria();
    _buscarDadosDoPedido();
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
  }

  Future<void> _buscarDadosDoPedido() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('pedidos_venda')
          .doc(widget.pedidoId)
          .get();

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;

        if (data['tokenAprovacao'] == widget.token) {
          setState(() {
            _dadosPedido = data;
            _confirmado = data['status'] != 'AGUARDANDO APROVAÇÃO DO CLIENTE';
            _carregando = false;
          });
        } else {
          setState(() {
            _mensagemErro = 'Link de aprovação inválido ou expirado.';
            _carregando = false;
          });
        }
      } else {
        setState(() {
          _mensagemErro = 'Pedido não localizado.';
          _carregando = false;
        });
      }
    } catch (e) {
      setState(() {
        _mensagemErro = 'Erro de conexão.';
        _carregando = false;
      });
    }
  }

  // =========================================================================
  // O MOTOR QUE DESENHA O PDF COM FOTOS (FOLHA A4) - CLIENTE
  // =========================================================================
  Future<Uint8List> _gerarPdf() async {
    final pdf = pw.Document();
    final dados = _dadosPedido!;
    final List itens = dados['itens'] ?? [];

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
                    pw.Text('Documento Auxiliar de Venda - Conferência'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Data: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
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
                      pw.Text('Tipo: ${dados['tipoVenda'] ?? '-'}'),
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
                0: const pw.FixedColumnWidth(40), // Foto
                1: const pw.FlexColumnWidth(1.2), // Ref
                2: const pw.FlexColumnWidth(2.5), // Produto
                3: const pw.FlexColumnWidth(4.5), // Grade
                4: const pw.FlexColumnWidth(0.8), // Qtd
                5: const pw.FlexColumnWidth(1.5), // Unit.
                6: const pw.FlexColumnWidth(1.5), // Subtotal
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
                      debugPrint('Erro ao renderizar foto: $e');
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

  void _abrirPdfParaCliente() async {
    final bytes = await _gerarPdf();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Pedido_NoEixo_${_dadosPedido!['clienteNome']}.pdf',
    );
  }

  Future<void> _confirmarPedidoOficialmente() async {
    setState(() => _carregando = true);
    try {
      await FirebaseFirestore.instance
          .collection('pedidos_venda')
          .doc(widget.pedidoId)
          .update({
            'status': 'ABERTO',
            'dataAprovacaoCliente': FieldValue.serverTimestamp(),
          });

      setState(() {
        _confirmado = true;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _mensagemErro = 'Falha ao confirmar. Tente novamente.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: _carregando
                  ? const SizedBox(
                      height: 150,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.green),
                      ),
                    )
                  : _mensagemErro.isNotEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(_mensagemErro, textAlign: TextAlign.center),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user,
                          color: Colors.indigo,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _dadosPedido!['clienteNome'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Valor do Pedido: R\$ ${(_dadosPedido!['valorFinalCobrado'] ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.indigo,
                              side: const BorderSide(color: Colors.indigo),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('VISUALIZAR ESPELHO DO PEDIDO'),
                            onPressed: _abrirPdfParaCliente,
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _confirmado
                                  ? Colors.grey.shade300
                                  : Colors.green,
                              foregroundColor: _confirmado
                                  ? Colors.grey.shade600
                                  : Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.green.shade800,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _confirmado
                                ? null
                                : _confirmarPedidoOficialmente,
                            icon: Icon(
                              _confirmado
                                  ? Icons.check_circle
                                  : Icons.touch_app,
                            ),
                            label: Text(
                              _confirmado
                                  ? 'PEDIDO CONFIRMADO'
                                  : 'CONFIRMAR PEDIDO',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        if (_confirmado)
                          const Padding(
                            padding: EdgeInsets.only(top: 16.0),
                            child: Text(
                              'Obrigado! Seu pedido já foi liberado para faturamento.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
