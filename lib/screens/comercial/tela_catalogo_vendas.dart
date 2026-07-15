import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaCatalogoVendas extends StatefulWidget {
  final String empresaId;

  const TelaCatalogoVendas({super.key, required this.empresaId});

  @override
  State<TelaCatalogoVendas> createState() => _TelaCatalogoVendasState();
}

class _TelaCatalogoVendasState extends State<TelaCatalogoVendas> {
  String _termoBusca = '';
  String _categoriaSelecionada = 'Todos';

  // Variáveis para a Gestão Dinâmica de Preços no Catálogo
  bool _isLoadingTabelas = true;
  List<Map<String, dynamic>> _tabelasDisponiveis = [];
  String? _tabelaAtivaId;
  Map<String, double> _precosDaTabelaAtiva = {};

  // --- CACHE DAS FICHAS TÉCNICAS E CORES ---
  bool _isLoadingFichas = true;
  bool _isLoadingCores = true;
  Map<String, Map<String, dynamic>> _fichasCache = {};
  Map<String, String> _coresImagensCache = {};

  @override
  void initState() {
    super.initState();
    _carregarTabelasDePreco();
    _carregarFichasTecnicas();
    _carregarCoresCache();
  }

  // =========================================================================
  // CARREGA AS TABELAS QUE O VENDEDOR PODE USAR
  // =========================================================================
  Future<void> _carregarTabelasDePreco() async {
    try {
      final tabelasSnap = await FirebaseFirestore.instance
          .collection('tabelas_preco')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .get();

      List<Map<String, dynamic>> lista = [];
      for (var doc in tabelasSnap.docs) {
        bool isAtiva = doc.data().containsKey('ativa')
            ? doc.data()['ativa']
            : true;
        if (isAtiva) {
          lista.add({
            'id': doc.id,
            'nome': doc.data()['nome'] ?? 'Tabela sem nome',
          });
        }
      }

      if (lista.isNotEmpty) {
        String tabelaInicial = lista.first['id'];
        for (var t in lista) {
          if (t['id'] == 'tabela_padrao') tabelaInicial = t['id'];
        }

        setState(() {
          _tabelasDisponiveis = lista;
          _tabelaAtivaId = tabelaInicial;
          _isLoadingTabelas = false;
        });

        await _buscarPrecosDaTabela(_tabelaAtivaId!);
      } else {
        setState(() => _isLoadingTabelas = false);
      }
    } catch (e) {
      debugPrint("Erro ao carregar tabelas: $e");
      setState(() => _isLoadingTabelas = false);
    }
  }

  Future<void> _buscarPrecosDaTabela(String tabelaId) async {
    try {
      final itensSnap = await FirebaseFirestore.instance
          .collection('tabelas_preco')
          .doc(tabelaId)
          .collection('itens')
          .get();

      Map<String, double> precosTemp = {};
      for (var doc in itensSnap.docs) {
        precosTemp[doc.id] =
            double.tryParse(doc.data()['preco']?.toString() ?? '0') ?? 0.0;
      }

      setState(() => _precosDaTabelaAtiva = precosTemp);
    } catch (e) {
      debugPrint("Erro ao carregar itens da tabela: $e");
    }
  }

  void _aoTrocarTabela(String novaTabelaId) {
    setState(() {
      _tabelaAtivaId = novaTabelaId;
      _precosDaTabelaAtiva.clear();
    });
    _buscarPrecosDaTabela(novaTabelaId);
  }

  // =========================================================================
  // CACHE DAS FICHAS TÉCNICAS E TEXTURAS DAS CORES
  // =========================================================================
  Future<void> _carregarFichasTecnicas() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('fichas_tecnicas')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .get();

      Map<String, Map<String, dynamic>> cacheTemp = {};
      for (var doc in snap.docs) {
        var data = doc.data();
        if (data['produtoId'] != null) {
          cacheTemp[data['produtoId']] = data;
        }
      }

      setState(() {
        _fichasCache = cacheTemp;
        _isLoadingFichas = false;
      });
    } catch (e) {
      debugPrint("Erro ao carregar Fichas: $e");
      setState(() => _isLoadingFichas = false);
    }
  }

  Future<void> _carregarCoresCache() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('cores').get();
      Map<String, String> cacheTemp = {};

      for (var doc in snap.docs) {
        var data = doc.data();
        if (data['nome'] != null &&
            data['imagemBase64'] != null &&
            data['imagemBase64'].toString().isNotEmpty) {
          cacheTemp[data['nome'].toString()] = data['imagemBase64'].toString();
        }
      }

      if (mounted) {
        setState(() {
          _coresImagensCache = cacheTemp;
          _isLoadingCores = false;
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar texturas das cores: $e");
      if (mounted) setState(() => _isLoadingCores = false);
    }
  }

  String _obterTecidoPrincipal(String produtoId) {
    if (!_fichasCache.containsKey(produtoId)) return '';

    List insumos = _fichasCache[produtoId]!['insumos'] ?? [];
    if (insumos.isEmpty) return '';

    for (var i in insumos) {
      String nome = (i['insumoNome'] ?? i['nome'] ?? i['descricao'] ?? '')
          .toString();
      String tipo = (i['tipo'] ?? i['categoria'] ?? '')
          .toString()
          .toUpperCase();

      if (tipo.contains('TECIDO') ||
          tipo.contains('MALHA') ||
          nome.toUpperCase().contains('MALHA') ||
          nome.toUpperCase().contains('SUEDINE') ||
          nome.toUpperCase().contains('COTTON') ||
          nome.toUpperCase().contains('RIBANA')) {
        return nome;
      }
    }

    return (insumos.first['insumoNome'] ?? insumos.first['nome'] ?? '')
        .toString();
  }

  // =========================================================================
  // MODAL DE LANÇAMENTO
  // =========================================================================
  void _abrirMatrizLancamento(
    Map<String, dynamic> produto,
    double precoAplicadoTabela,
    String produtoId,
  ) {
    List<String> tamanhos = [];
    List<String> cores = [];

    if (_fichasCache.containsKey(produtoId)) {
      tamanhos = List<String>.from(_fichasCache[produtoId]!['tamanhos'] ?? []);
      cores = List<String>.from(
        _fichasCache[produtoId]!['coresComerciais'] ?? [],
      );
    }

    if (tamanhos.isEmpty) tamanhos = ['Único'];
    if (cores.isEmpty) cores = ['Cor Única'];

    Map<String, Map<String, TextEditingController>> matrizControllers = {};
    int multiplicadorGrade = 0;
    bool sortidoPorCor = false;

    // --- VARIÁVEIS DA CALCULADORA DE DESCONTO OCULTA ---
    bool mostrarCalculadoraDesconto = false;
    double precoNegociado = precoAplicadoTabela;
    double percentualDesconto = 0.0;

    // Deixamos os controladores vazios inicialmente para não forçar o vendedor a apagar
    final TextEditingController percCtrl = TextEditingController();
    final TextEditingController precoCtrl = TextEditingController();

    for (String cor in cores) {
      matrizControllers[cor] = {};
      for (String tam in tamanhos) {
        matrizControllers[cor]![tam] = TextEditingController();
      }
    }

    Map<String, TextEditingController> sortidoControllers = {};
    for (String tam in tamanhos) {
      sortidoControllers[tam] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Color getCorFundoDesconto() {
              if (percentualDesconto <= 0) return Colors.grey.shade100;
              if (percentualDesconto <= 10) return Colors.blue.shade50;
              if (percentualDesconto <= 15) return Colors.amber.shade50;
              if (percentualDesconto <= 20) return Colors.orange.shade50;
              if (percentualDesconto <= 25) return Colors.red.shade50;
              return Colors.deepPurple.shade50;
            }

            Color getCorTextoDesconto() {
              if (percentualDesconto <= 0) return Colors.blueGrey;
              if (percentualDesconto <= 10) return Colors.blue.shade900;
              if (percentualDesconto <= 15) return Colors.amber.shade900;
              if (percentualDesconto <= 20) return Colors.orange.shade900;
              if (percentualDesconto <= 25) return Colors.red.shade900;
              return Colors.deepPurple.shade900;
            }

            // ATUALIZAÇÃO BIDIRECIONAL COM CAMPOS "LIMPOS"
            void aoMudarPercentual(String val) {
              double perc = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
              if (perc < 0) perc = 0;
              double novoP = precoAplicadoTabela * (1 - (perc / 100));

              setModalState(() {
                percentualDesconto = perc;
                precoNegociado = novoP;
                // Atualiza o outro campo apenas se houver valor, senão deixa vazio
                if (val.isEmpty || perc == 0) {
                  precoCtrl.text = '';
                } else {
                  String novoPTxt = novoP.toStringAsFixed(2);
                  if (precoCtrl.text != novoPTxt) {
                    precoCtrl.text = novoPTxt;
                    precoCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: precoCtrl.text.length),
                    );
                  }
                }
              });
            }

            void aoMudarPreco(String val) {
              double preco =
                  double.tryParse(val.replaceAll(',', '.')) ??
                  precoAplicadoTabela;
              double perc =
                  ((precoAplicadoTabela - preco) / precoAplicadoTabela) * 100;
              if (perc < 0) perc = 0;

              setModalState(() {
                precoNegociado = preco;
                percentualDesconto = perc;

                if (val.isEmpty || preco == precoAplicadoTabela) {
                  percCtrl.text = '';
                } else {
                  String novoPercTxt = perc.toStringAsFixed(1);
                  if (percCtrl.text != novoPercTxt) {
                    percCtrl.text = novoPercTxt;
                    percCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: percCtrl.text.length),
                    );
                  }
                }
              });
            }

            double calcularTotal() {
              int totalPecas = 0;
              if (sortidoPorCor) {
                sortidoControllers.forEach(
                  (_, ctrl) => totalPecas += int.tryParse(ctrl.text) ?? 0,
                );
              } else {
                matrizControllers.forEach(
                  (_, tMap) => tMap.forEach(
                    (_, ctrl) => totalPecas += int.tryParse(ctrl.text) ?? 0,
                  ),
                );
              }
              return totalPecas * precoNegociado;
            }

            void aplicarMultiplicadorGrade(int incremento) {
              setModalState(() {
                multiplicadorGrade += incremento;
                if (multiplicadorGrade < 0) multiplicadorGrade = 0;
                String valorTexto = multiplicadorGrade > 0
                    ? multiplicadorGrade.toString()
                    : '';

                if (sortidoPorCor) {
                  sortidoControllers.forEach(
                    (_, ctrl) => ctrl.text = valorTexto,
                  );
                } else {
                  matrizControllers.forEach(
                    (_, tMap) =>
                        tMap.forEach((_, ctrl) => ctrl.text = valorTexto),
                  );
                }
              });
            }

            Widget imagemWidget = Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.grey.shade200,
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child:
                        (produto['fotoBase64'] != null &&
                            produto['fotoBase64'].toString().isNotEmpty)
                        ? Image.memory(
                            base64Decode(produto['fotoBase64']),
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.inventory,
                            size: 80,
                            color: Colors.grey,
                          ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            );

            Widget formularioWidget = Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produto['nome'] ?? 'Sem Nome',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      Text(
                        'Ref: ${produto['referencia'] ?? 'S/R'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (!mostrarCalculadoraDesconto)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'R\$ ${precoAplicadoTabela.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.local_offer_outlined,
                                color: Colors.grey,
                                size: 22,
                              ),
                              tooltip: 'Negociar Preço da Peça',
                              onPressed: () => setModalState(
                                () => mostrarCalculadoraDesconto = true,
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: getCorFundoDesconto(),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: getCorTextoDesconto().withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Preço Original (Tabela):',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'R\$ ${precoAplicadoTabela.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey,
                                          decoration: percentualDesconto > 0
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      InkWell(
                                        onTap: () {
                                          setModalState(() {
                                            percentualDesconto = 0.0;
                                            precoNegociado =
                                                precoAplicadoTabela;
                                            percCtrl.clear();
                                            precoCtrl.clear();
                                            mostrarCalculadoraDesconto = false;
                                          });
                                        },
                                        child: const Icon(
                                          Icons.cancel,
                                          size: 20,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: percCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: getCorTextoDesconto(),
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Desconto (%)',
                                        hintText:
                                            '0.0', // <-- HINT EXIBIDO QUANDO VAZIO
                                        labelStyle: TextStyle(
                                          color: getCorTextoDesconto(),
                                        ),
                                        suffixIcon: Icon(
                                          Icons.percent,
                                          size: 16,
                                          color: getCorTextoDesconto(),
                                        ),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: getCorTextoDesconto(),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: getCorTextoDesconto()
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: getCorTextoDesconto(),
                                            width: 2,
                                          ),
                                        ),
                                        isDense: true,
                                      ),
                                      onChanged: aoMudarPercentual,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: precoCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: getCorTextoDesconto(),
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Preço Final (R\$)',
                                        hintText: precoAplicadoTabela
                                            .toStringAsFixed(
                                              2,
                                            ), // <-- HINT EXIBIDO QUANDO VAZIO
                                        labelStyle: TextStyle(
                                          color: getCorTextoDesconto(),
                                        ),
                                        prefixText: 'R\$ ',
                                        prefixStyle: TextStyle(
                                          color: getCorTextoDesconto(),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: getCorTextoDesconto(),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: getCorTextoDesconto()
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: getCorTextoDesconto(),
                                            width: 2,
                                          ),
                                        ),
                                        isDense: true,
                                      ),
                                      onChanged: aoMudarPreco,
                                    ),
                                  ),
                                ],
                              ),
                              if (percentualDesconto > 25)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '⚠️ Bloqueado: Exige autorização da Diretoria.',
                                    style: TextStyle(
                                      color: Colors.deepPurple,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Aplicar quantidade rápida na grade:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove,
                                    color: Colors.teal,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      aplicarMultiplicadorGrade(-1),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                                Text(
                                  '${multiplicadorGrade}x',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade800,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.teal,
                                    size: 18,
                                  ),
                                  onPressed: () => aplicarMultiplicadorGrade(1),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Sortido por Cor',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'O sistema define o mix inteligente de envio.',
                            ),
                            activeColor: Colors.teal,
                            value: sortidoPorCor,
                            onChanged: (bool? value) => setModalState(
                              () => sortidoPorCor = value ?? false,
                            ),
                          ),
                          const Divider(),
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Cores',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ...tamanhos.map(
                                (t) => Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Text(
                                      t,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (sortidoPorCor)
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: SweepGradient(
                                            colors: [
                                              Colors.red,
                                              Colors.blue,
                                              Colors.yellow,
                                              Colors.green,
                                              Colors.red,
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Sortidas',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...tamanhos.map(
                                  (t) => Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: TextFormField(
                                        controller: sortidoControllers[t],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.zero,
                                          isDense: true,
                                        ),
                                        onChanged: (_) => setModalState(() {}),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            ...cores.map((cor) {
                              String? base64Img = _coresImagensCache[cor];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 8,
                                            backgroundColor:
                                                Colors.grey.shade300,
                                            backgroundImage:
                                                (base64Img != null &&
                                                    base64Img.isNotEmpty)
                                                ? MemoryImage(
                                                    base64Decode(base64Img),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              cor,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...tamanhos.map(
                                      (t) => Expanded(
                                        flex: 1,
                                        child: Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: TextFormField(
                                            controller:
                                                matrizControllers[cor]![t],
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.zero,
                                              isDense: true,
                                            ),
                                            onChanged: (_) =>
                                                setModalState(() {}),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
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
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Subtotal',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'R\$ ${calcularTotal().toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text(
                              'Lançar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: () {
                              List<Map<String, dynamic>> subItens = [];
                              if (sortidoPorCor) {
                                sortidoControllers.forEach((tam, ctrl) {
                                  int qtd = int.tryParse(ctrl.text) ?? 0;
                                  if (qtd > 0)
                                    subItens.add({
                                      'cor': 'Sortida',
                                      'tamanho': tam,
                                      'quantidade': qtd,
                                    });
                                });
                              } else {
                                matrizControllers.forEach((cor, tMap) {
                                  tMap.forEach((tam, ctrl) {
                                    int qtd = int.tryParse(ctrl.text) ?? 0;
                                    if (qtd > 0)
                                      subItens.add({
                                        'cor': cor,
                                        'tamanho': tam,
                                        'quantidade': qtd,
                                      });
                                  });
                                });
                              }

                              int qtdTotal = subItens.fold(
                                0,
                                (sum, i) => sum + (i['quantidade'] as int),
                              );

                              if (qtdTotal == 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Informe a quantidade de pelo menos uma peça!',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              Map<String, dynamic> itemParaCarrinho = {
                                'idTemporario': DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                'produtoId': produtoId,
                                'referencia': produto['referencia'] ?? 'S/R',
                                'nome': produto['nome'] ?? 'Produto',
                                'fotoBase64': produto['fotoBase64'],
                                'precoTabela': precoAplicadoTabela,
                                'precoVendido': precoNegociado,
                                'quantidadeTotal': qtdTotal,
                                'valorTotal': qtdTotal * precoNegociado,
                                'gradeDistribuicao': subItens,
                              };

                              Navigator.pop(context);
                              Navigator.pop(context, itemParaCarrinho);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );

            bool isDesktop = MediaQuery.of(context).size.width > 800;

            return Dialog(
              insetPadding: EdgeInsets.all(isDesktop ? 60 : 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: isDesktop
                  ? Row(
                      children: [
                        Expanded(flex: 5, child: imagemWidget),
                        Expanded(flex: 5, child: formularioWidget),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(flex: 4, child: imagemWidget),
                        Expanded(flex: 6, child: formularioWidget),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double larguraTela = MediaQuery.of(context).size.width;
    int numeroColunas = larguraTela > 1200
        ? 5
        : larguraTela > 900
        ? 4
        : larguraTela > 600
        ? 3
        : 2;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Catálogo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: (_isLoadingTabelas || _isLoadingFichas || _isLoadingCores)
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Column(
              children: [
                Container(
                  color: Colors.teal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Pesquisar modelo ou referência...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.teal,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) =>
                            setState(() => _termoBusca = val.toLowerCase()),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.request_quote,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Tabela Ativa:',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  dropdownColor: Colors.teal.shade800,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  value: _tabelaAtivaId,
                                  items: _tabelasDisponiveis
                                      .map(
                                        (t) => DropdownMenuItem<String>(
                                          value: t['id'],
                                          child: Text(t['nome']),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (novoId) {
                                    if (novoId != null) _aoTrocarTabela(novoId);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('produtos')
                        .where('empresa_id', isEqualTo: widget.empresaId)
                        .where('tipo', isEqualTo: 'Produto Acabado')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                        return const Center(
                          child: Text('Nenhum produto cadastrado.'),
                        );

                      Set<String> categoriasUnicas = {'Todos'};
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['categoria'] != null &&
                            data['categoria'].toString().trim().isNotEmpty) {
                          categoriasUnicas.add(
                            data['categoria'].toString().trim(),
                          );
                        }
                      }
                      List<String> listaCategorias = categoriasUnicas.toList();

                      var produtosFiltrados = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final nome = (data['nome'] ?? '')
                            .toString()
                            .toLowerCase();
                        final ref = (data['referencia'] ?? '')
                            .toString()
                            .toLowerCase();
                        final categoria = data['categoria'] ?? '';

                        bool atendeBusca =
                            _termoBusca.isEmpty ||
                            nome.contains(_termoBusca) ||
                            ref.contains(_termoBusca);
                        bool atendeCategoria =
                            _categoriaSelecionada == 'Todos' ||
                            categoria == _categoriaSelecionada;

                        return atendeBusca && atendeCategoria;
                      }).toList();

                      return Column(
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: listaCategorias
                                  .map(
                                    (cat) => Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: ChoiceChip(
                                        label: Text(cat),
                                        selected: _categoriaSelecionada == cat,
                                        selectedColor: Colors.teal.shade100,
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                          color: _categoriaSelecionada == cat
                                              ? Colors.teal
                                              : Colors.grey.shade300,
                                        ),
                                        onSelected: (selecionado) => setState(
                                          () => _categoriaSelecionada =
                                              selecionado ? cat : 'Todos',
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          Expanded(
                            child: produtosFiltrados.isEmpty
                                ? const Center(
                                    child: Text('Nenhum produto encontrado.'),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(8),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: numeroColunas,
                                          childAspectRatio: 0.65,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                        ),
                                    itemCount: produtosFiltrados.length,
                                    itemBuilder: (context, index) {
                                      final docId = produtosFiltrados[index].id;
                                      final data =
                                          produtosFiltrados[index].data()
                                              as Map<String, dynamic>;

                                      double precoFinal =
                                          _precosDaTabelaAtiva[docId] ?? 0.0;
                                      String tecidoInfo = _obterTecidoPrincipal(
                                        docId,
                                      );

                                      return GestureDetector(
                                        onTap: () => _abrirMatrizLancamento(
                                          data,
                                          precoFinal,
                                          docId,
                                        ),
                                        child: Card(
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Expanded(
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Container(
                                                      color:
                                                          Colors.grey.shade200,
                                                      child:
                                                          (data['fotoBase64'] !=
                                                                  null &&
                                                              data['fotoBase64']
                                                                  .toString()
                                                                  .isNotEmpty)
                                                          ? Image.memory(
                                                              base64Decode(
                                                                data['fotoBase64'],
                                                              ),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : const Icon(
                                                              Icons
                                                                  .image_not_supported,
                                                              color:
                                                                  Colors.grey,
                                                              size: 40,
                                                            ),
                                                    ),
                                                    Positioned(
                                                      bottom: 8,
                                                      right: 8,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 3,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white
                                                              .withOpacity(
                                                                0.95,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                          boxShadow: const [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black26,
                                                              blurRadius: 2,
                                                              offset: Offset(
                                                                1,
                                                                1,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Text(
                                                          precoFinal > 0
                                                              ? 'R\$ ${precoFinal.toStringAsFixed(2)}'
                                                              : 'Sob Consulta',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                precoFinal > 0
                                                                ? Colors.black87
                                                                : Colors.red,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      data['referencia'] ??
                                                          'S/R',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      data['nome'] ?? '',
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.blueGrey,
                                                      ),
                                                    ),

                                                    if (tecidoInfo.isNotEmpty)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 4.0,
                                                            ),
                                                        child: Text(
                                                          tecidoInfo,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .indigo,
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                              ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
