import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'form_entrada_manual.dart';
import 'form_entrada_itens.dart';

class TelaEntradaConferencia extends StatefulWidget {
  const TelaEntradaConferencia({super.key});

  @override
  State<TelaEntradaConferencia> createState() => _TelaEntradaConferenciaState();
}

class _TelaEntradaConferenciaState extends State<TelaEntradaConferencia> {
  // ==========================================
  // VARIÁVEIS DE FILTRAGEM E DICIONÁRIOS
  // ==========================================
  DateTime? _dataInicial;
  DateTime? _dataFinal;
  String _termoBuscaFornecedor = '';
  String _termoBuscaItem = '';

  // Controladores para limpar os campos preditivos
  final _fornFilterCtrl = TextEditingController();
  final _itemFilterCtrl = TextEditingController();

  // Dicionários para carregar os nomes reais e alimentar o Autocomplete
  Map<String, String> _mapaFornecedores = {};
  List<String> _nomesInsumosCadastrados = [];
  bool _carregandoBases = true;

  @override
  void initState() {
    super.initState();
    _carregarListasBase();
  }

  @override
  void dispose() {
    _fornFilterCtrl.dispose();
    _itemFilterCtrl.dispose();
    super.dispose();
  }

  // Carrega todos os fornecedores e insumos para o sistema "saber" os nomes
  Future<void> _carregarListasBase() async {
    try {
      var fornSnap = await FirebaseFirestore.instance
          .collection('fornecedores')
          .where('clienteId', isEqualTo: 'teste_textil')
          .get();
      var insSnap = await FirebaseFirestore.instance
          .collection('insumos')
          .where('clienteId', isEqualTo: 'teste_textil')
          .get();

      Map<String, String> mapaForn = {};
      for (var doc in fornSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String nome =
            data['nomeFantasia'] ??
            data['razaoSocial'] ??
            data['nome'] ??
            'Sem nome';
        mapaForn[doc.id] = nome;
      }

      List<String> nomesIns = [];
      for (var doc in insSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['nome'] != null) nomesIns.add(data['nome'].toString());
      }

      if (mounted) {
        setState(() {
          _mapaFornecedores = mapaForn;
          _nomesInsumosCadastrados = nomesIns;
          _carregandoBases = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _carregandoBases = false);
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Future<void> _selecionarPeriodo() async {
    final DateTimeRange? periodo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.blueGrey,
            ),
          ),
          child: child!,
        );
      },
    );

    if (periodo != null) {
      setState(() {
        _dataInicial = periodo.start;
        _dataFinal = periodo.end;
      });
    }
  }

  void _limparFiltros() {
    setState(() {
      _dataInicial = null;
      _dataFinal = null;
      _termoBuscaFornecedor = '';
      _termoBuscaItem = '';
      _fornFilterCtrl.clear();
      _itemFilterCtrl.clear();
    });
  }

  // ==========================================
  // LÓGICA DE AUDITORIA E ESTORNO (COM LEITURA DE ITENS)
  // ==========================================
  void _mostrarPainelAuditoria(String idDoc, Map<String, dynamic> dadosNota) {
    String idForn = dadosNota['fornecedorId'] ?? '';
    String nomeForn = _mapaFornecedores[idForn] ?? 'Fornecedor Desconhecido';
    List<dynamic> itensLancados = dadosNota['itens'] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Conferência e Auditoria',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documento: ${dadosNota['numeroDocumento'] ?? 'S/N'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Fornecedor: $nomeForn',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // --- SESSÃO VISUAL DE LEITURA DOS ITENS ---
              const Text(
                'Itens da Nota:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const Divider(),
              Flexible(
                child: itensLancados.isEmpty
                    ? const Text(
                        'Nenhum item registrado nesta nota.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: itensLancados.length,
                        itemBuilder: (context, index) {
                          final item = itensLancados[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.teal.shade50,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.teal.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['nomeInsumo'] ??
                                            'Item Desconhecido',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Qtde: ${item['quantidade']} x R\$ ${item['valorUnitario']} = R\$ ${item['valorTotal']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),

              // ------------------------------------------
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Compliance: Entradas efetivadas não podem ser editadas. Em caso de erro, estorne a nota. O sistema irá remover o saldo do estoque, apagar o financeiro e excluir este registo.',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'VOLTAR',
              style: TextStyle(color: Colors.blueGrey),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text('ESTORNAR NOTA'),
            onPressed: () async {
              try {
                // 1. Prepara o Batch para garantir que tudo apaga ou nada apaga
                WriteBatch batch = FirebaseFirestore.instance.batch();

                // 2. Reverter Saldo do Estoque
                for (var item in itensLancados) {
                  if (item['tipo'] == 'Insumo' && item['insumoId'] != null) {
                    DocumentReference refInsumo = FirebaseFirestore.instance
                        .collection('insumos')
                        .doc(item['insumoId']);
                    batch.update(refInsumo, {
                      'estoqueAtual': FieldValue.increment(
                        -(item['quantidade'] ?? 0),
                      ),
                    });
                  }
                }

                // 3. Excluir contas a pagar vinculadas
                var contasSnapshot = await FirebaseFirestore.instance
                    .collection('contas_a_pagar')
                    .where('entradaEstoqueId', isEqualTo: idDoc)
                    .get();
                for (var conta in contasSnapshot.docs) {
                  batch.delete(conta.reference);
                }

                // 4. Excluir a Nota
                DocumentReference refNota = FirebaseFirestore.instance
                    .collection('entradas_estoque')
                    .doc(idDoc);
                batch.delete(refNota);

                // Efetiva a transação
                await batch.commit();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Nota estornada com sucesso. Estoque revertido.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao estornar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SELETOR DE ENTRADA
  // ==========================================
  void _abrirOpcoesEntrada(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Como deseja registrar a entrada?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.qr_code_scanner, color: Colors.white),
                  ),
                  title: const Text(
                    'Importar XML Automático',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Lê os itens e gera o financeiro sozinho.',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Módulo XML em desenvolvimento.'),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: const Icon(Icons.keyboard, color: Colors.teal),
                  ),
                  title: const Text(
                    'Digitação Manual',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Notas Frias, Recibos ou Ajustes.'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FormEntradaManual(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Entrada e Conferência',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _carregandoBases
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // CABEÇALHO VISUAL
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.teal.shade700,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Painel de Recebimento',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Acompanhe e efetive suas notas',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // MOTOR DE FILTROS PREDITIVOS (AUTOCOMPLETE)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selecionarPeriodo,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Colors.teal.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _dataInicial == null
                                            ? 'Filtrar por Período'
                                            : '${_formatarData(_dataInicial!)} até ${_formatarData(_dataFinal!)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _dataInicial == null
                                              ? Colors.grey
                                              : Colors.black87,
                                          fontWeight: _dataInicial == null
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_dataInicial != null ||
                              _termoBuscaFornecedor.isNotEmpty ||
                              _termoBuscaItem.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              tooltip: 'Limpar Filtros',
                              onPressed: _limparFiltros,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // AUTOCOMPLETE FORNECEDOR
                          Expanded(
                            child: Autocomplete<String>(
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty)
                                      return const Iterable<String>.empty();
                                    return _mapaFornecedores.values.where((
                                      String option,
                                    ) {
                                      return option.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      );
                                    });
                                  },
                              onSelected: (String selection) {
                                setState(
                                  () => _termoBuscaFornecedor = selection
                                      .toLowerCase(),
                                );
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    // Vincula o controlador interno ao nosso controlador para podermos limpar via código
                                    if (controller.text !=
                                        _fornFilterCtrl.text) {
                                      controller.text = _fornFilterCtrl.text;
                                    }
                                    controller.addListener(() {
                                      _fornFilterCtrl.text = controller.text;
                                    });

                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        hintText: 'Fornecedor',
                                        prefixIcon: const Icon(
                                          Icons.business,
                                          size: 18,
                                        ),
                                        isDense: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onChanged: (v) => setState(
                                        () => _termoBuscaFornecedor = v
                                            .toLowerCase(),
                                      ),
                                    );
                                  },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // AUTOCOMPLETE INSUMO
                          Expanded(
                            child: Autocomplete<String>(
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty)
                                      return const Iterable<String>.empty();
                                    return _nomesInsumosCadastrados.where((
                                      String option,
                                    ) {
                                      return option.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      );
                                    });
                                  },
                              onSelected: (String selection) {
                                setState(
                                  () =>
                                      _termoBuscaItem = selection.toLowerCase(),
                                );
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    if (controller.text !=
                                        _itemFilterCtrl.text) {
                                      controller.text = _itemFilterCtrl.text;
                                    }
                                    controller.addListener(() {
                                      _itemFilterCtrl.text = controller.text;
                                    });

                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        hintText: 'Item / Insumo',
                                        prefixIcon: const Icon(
                                          Icons.inventory_2,
                                          size: 18,
                                        ),
                                        isDense: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onChanged: (v) => setState(
                                        () => _termoBuscaItem = v.toLowerCase(),
                                      ),
                                    );
                                  },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // LISTA DE NOTAS/ENTRADAS COM RESOLUÇÃO DE NOMES
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('entradas_estoque')
                        .where('clienteId', isEqualTo: 'teste_textil')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return Center(
                          child: Text(
                            'Erro ao carregar dados:\n${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Nenhuma entrada registrada.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      // Aplicação dos Filtros Cruzados Humanizados
                      var documentos = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        // 1. Filtro de Data
                        if (_dataInicial != null && _dataFinal != null) {
                          Timestamp? tData = data['dataRegistro'] as Timestamp?;
                          if (tData == null) return false;
                          DateTime dataRegistro = tData.toDate();
                          if (dataRegistro.isBefore(_dataInicial!) ||
                              dataRegistro.isAfter(
                                _dataFinal!.add(const Duration(days: 1)),
                              ))
                            return false;
                        }

                        // 2. Filtro de Fornecedor
                        String idForn = data['fornecedorId'] ?? '';
                        String nomeFornResolvido =
                            (_mapaFornecedores[idForn] ?? 'Sem Nome')
                                .toLowerCase();

                        if (_termoBuscaFornecedor.isNotEmpty) {
                          if (!nomeFornResolvido.contains(
                            _termoBuscaFornecedor,
                          ))
                            return false;
                        }

                        // 3. Filtro de Insumo Cruzado
                        if (_termoBuscaItem.isNotEmpty) {
                          List<dynamic> itensNaNota = data['itens'] ?? [];
                          bool temItem = itensNaNota.any((item) {
                            String nomeItem = (item['nomeInsumo'] ?? '')
                                .toString()
                                .toLowerCase();
                            return nomeItem.contains(_termoBuscaItem);
                          });
                          if (!temItem) return false;
                        }

                        return true;
                      }).toList();

                      if (documentos.isEmpty)
                        return const Center(
                          child: Text(
                            'Nenhuma nota corresponde aos filtros.',
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        );

                      // Ordenação Local
                      documentos.sort((a, b) {
                        Timestamp? tA =
                            (a.data() as Map<String, dynamic>)['dataRegistro']
                                as Timestamp?;
                        Timestamp? tB =
                            (b.data() as Map<String, dynamic>)['dataRegistro']
                                as Timestamp?;
                        if (tA == null && tB == null) return 0;
                        if (tA == null) return 1;
                        if (tB == null) return -1;
                        return tB.compareTo(tA);
                      });

                      return Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 16,
                            ),
                            color: Colors.teal.shade50,
                            child: Text(
                              'Exibindo ${documentos.length} nota(s)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.teal.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: documentos.length,
                              itemBuilder: (context, index) {
                                final doc = documentos[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final String status =
                                    data['status'] ?? 'Pendente';
                                final bool isDigitacao =
                                    status == 'Em Digitação';

                                // Traduz o ID encriptado para o Nome Real
                                String idForn = data['fornecedorId'] ?? '';
                                String nomeFornecedorFinal =
                                    _mapaFornecedores[idForn] ??
                                    'Desconhecido ($idForn)';

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    onTap: () {
                                      if (isDigitacao) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FormEntradaItens(
                                                  tipoDocumento:
                                                      data['tipoDocumento'],
                                                  numeroDocumento:
                                                      data['numeroDocumento'],
                                                  fornecedorId:
                                                      data['fornecedorId'],
                                                  documentoId: doc.id,
                                                ),
                                          ),
                                        );
                                      } else {
                                        // ABRE O PAINEL DE ESTORNO COM LEITURA DOS ITENS
                                        _mostrarPainelAuditoria(doc.id, data);
                                      }
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: isDigitacao
                                          ? Colors.orange.shade100
                                          : Colors.green.shade100,
                                      child: Icon(
                                        isDigitacao
                                            ? Icons.edit_note
                                            : Icons.check_circle,
                                        color: isDigitacao
                                            ? Colors.orange.shade800
                                            : Colors.green.shade800,
                                      ),
                                    ),
                                    title: Text(
                                      'Doc: ${data['numeroDocumento'] != null && data['numeroDocumento'].toString().isNotEmpty ? data['numeroDocumento'] : 'S/N'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(data['tipoDocumento'] ?? ''),
                                        Text(
                                          'Valor: R\$ ${(data['valorTotal'] ?? 0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            'Forn: $nomeFornecedorFinal',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.teal.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDigitacao
                                                ? Colors.orange
                                                : Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Icon(
                                          Icons.chevron_right,
                                          size: 16,
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        onPressed: () => _abrirOpcoesEntrada(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Registrar Entrada',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
