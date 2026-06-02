import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo para o Laboratório (Aba 2)
class CenarioSimulacao {
  final String id;
  String nome;
  final Map<String, TextEditingController> controladores;

  CenarioSimulacao({
    required this.id,
    required this.nome,
    required this.controladores,
  });
}

class TelaLaboratorioPrecos extends StatefulWidget {
  final String empresaId;

  const TelaLaboratorioPrecos({super.key, required this.empresaId});

  @override
  State<TelaLaboratorioPrecos> createState() => _TelaLaboratorioPrecosState();
}

class _TelaLaboratorioPrecosState extends State<TelaLaboratorioPrecos> {
  bool _isLoading = true;

  // Dados Globais
  List<Map<String, dynamic>> _produtos = [];
  Map<String, double> _precosPadraoIniciais = {};

  // Filtros Dinâmicos Globais
  String _termoBusca = '';
  String _categoriaSelecionada = 'Todas';
  List<String> _categoriasDinamicas = ['Todas'];

  // --- ESTADOS DA ABA 1 (TABELAS OFICIAIS) ---
  List<Map<String, dynamic>> _listaTabelasOficiais = [];
  String _tabelaOficialAtivaId = 'tabela_padrao';
  final Map<String, TextEditingController> _tab1Controladores = {};
  bool _mostrarInativas = false; // Oculta tabelas inativas por padrão

  // --- ESTADOS DA ABA 2 (LABORATÓRIO) ---
  List<CenarioSimulacao> _cenarios = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosGerais();
  }

  @override
  void dispose() {
    for (var ctrl in _tab1Controladores.values) {
      ctrl.dispose();
    }
    for (var cenario in _cenarios) {
      for (var ctrl in cenario.controladores.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  // =========================================================================
  // MOTOR DE CARREGAMENTO
  // =========================================================================
  Future<void> _carregarDadosGerais() async {
    setState(() => _isLoading = true);

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // 1. Produtos
      final produtosSnap = await firestore
          .collection('produtos')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('tipo', isEqualTo: 'Produto Acabado')
          .get();

      Set<String> categoriasSet = {'Todas'};
      List<Map<String, dynamic>> listaProdTemp = [];

      for (var doc in produtosSnap.docs) {
        final data = doc.data();
        String cat = data['categoria']?.toString().trim() ?? 'Sem Categoria';
        if (cat.isNotEmpty) categoriasSet.add(cat);

        listaProdTemp.add({
          'id': doc.id,
          'referencia': data['referencia'] ?? '',
          'nome': data['nome'] ?? '',
          'categoria': cat,
        });
      }
      listaProdTemp.sort(
        (a, b) =>
            a['referencia'].toString().compareTo(b['referencia'].toString()),
      );

      // 2. Tabelas (Lê o status de ATIVA)
      final tabelasSnap = await firestore
          .collection('tabelas_preco')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .get();

      List<Map<String, dynamic>> listaTabTemp = [];
      bool temTabelaPadrao = false;

      for (var doc in tabelasSnap.docs) {
        if (doc.id == 'tabela_padrao') temTabelaPadrao = true;

        // Pega o status, se não existir assume como verdadeira (ativa)
        bool isAtiva = true;
        if (doc.data().containsKey('ativa')) {
          isAtiva = doc.data()['ativa'] as bool;
        }

        listaTabTemp.add({
          'id': doc.id,
          'nome': doc.data()['nome'] ?? 'Tabela Sem Nome',
          'ativa': isAtiva,
        });
      }

      if (!temTabelaPadrao) {
        listaTabTemp.insert(0, {
          'id': 'tabela_padrao',
          'nome': 'Tabela Padrão',
          'ativa': true,
        });
      }

      // 3. Preços Base (Trava de Vidro)
      final padraoSnap = await firestore
          .collection('tabelas_preco')
          .doc('tabela_padrao')
          .collection('itens')
          .get();
      _precosPadraoIniciais.clear();
      for (var doc in padraoSnap.docs) {
        _precosPadraoIniciais[doc.id] =
            double.tryParse(doc.data()['preco']?.toString() ?? '0') ?? 0.0;
      }

      setState(() {
        _produtos = listaProdTemp;
        _categoriasDinamicas = categoriasSet.toList();
        _listaTabelasOficiais = listaTabTemp;
        if (!_categoriasDinamicas.contains(_categoriaSelecionada))
          _categoriaSelecionada = 'Todas';
      });

      await _carregarItensTabelaOficial(_tabelaOficialAtivaId);
    } catch (e) {
      debugPrint("Erro ao carregar dados: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _carregarItensTabelaOficial(String tabelaId) async {
    setState(() => _isLoading = true);
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

      for (var prod in _produtos) {
        double preco = precosTemp[prod['id']] ?? 0.0;
        if (_tab1Controladores.containsKey(prod['id'])) {
          _tab1Controladores[prod['id']]!.text = preco > 0
              ? preco.toStringAsFixed(2)
              : '';
        } else {
          _tab1Controladores[prod['id']] = TextEditingController(
            text: preco > 0 ? preco.toStringAsFixed(2) : '',
          );
        }
      }

      setState(() {
        _tabelaOficialAtivaId = tabelaId;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erro ao carregar itens: $e");
      setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // ABA 1 - MANUTENÇÃO (GRAVAR, ATIVAR E INATIVAR)
  // =========================================================================
  Future<void> _gravarTabelaOficial() async {
    setState(() => _isLoading = true);
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      DocumentReference tabelaRef = firestore
          .collection('tabelas_preco')
          .doc(_tabelaOficialAtivaId);
      batch.set(tabelaRef, {
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (var prod in _produtos) {
        double precoDigitado =
            double.tryParse(
              _tab1Controladores[prod['id']]!.text.replaceAll(',', '.'),
            ) ??
            0.0;
        if (precoDigitado > 0) {
          batch.set(tabelaRef.collection('itens').doc(prod['id']), {
            'preco': precoDigitado,
            'atualizadoEm': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (_tabelaOficialAtivaId == 'tabela_padrao') {
        await _carregarDadosGerais();
      }

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Valores atualizados com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gravar: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // O Motor de Inativar/Reativar
  Future<void> _alternarStatusTabela(bool statusAtual) async {
    if (_tabelaOficialAtivaId == 'tabela_padrao') return; // Segurança dupla

    bool novoStatus = !statusAtual;
    String acaoTxt = novoStatus ? 'Reativar' : 'Inativar';

    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$acaoTxt Tabela?'),
            content: Text(
              novoStatus
                  ? 'Esta tabela voltará a aparecer para os vendedores no Catálogo.'
                  : 'Esta tabela desaparecerá da visão de todos, mas o histórico será mantido.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: novoStatus ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Sim, $acaoTxt'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('tabelas_preco')
          .doc(_tabelaOficialAtivaId)
          .set({
            'ativa': novoStatus,
            'atualizadoEm': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tabela $acaoTxt com sucesso!'),
            backgroundColor: Colors.orange,
          ),
        );

      // Volta para a Tabela Padrão após inativar para limpar a tela
      if (!novoStatus && !_mostrarInativas) {
        _tabelaOficialAtivaId = 'tabela_padrao';
      }

      await _carregarDadosGerais();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // ABA 2 - LABORATÓRIO (O ROTEADOR DE SUBSTITUIÇÃO)
  // =========================================================================
  void _adicionarNovoCenario() {
    String novoId = DateTime.now().millisecondsSinceEpoch.toString();
    Map<String, TextEditingController> novosControladores = {};

    for (var prod in _produtos) {
      double precoBase = _precosPadraoIniciais[prod['id']] ?? 0.0;
      novosControladores[prod['id']] = TextEditingController(
        text: precoBase > 0 ? precoBase.toStringAsFixed(2) : '',
      );
    }

    setState(() {
      _cenarios.add(
        CenarioSimulacao(
          id: novoId,
          nome: 'Simulação ${_cenarios.length + 1}',
          controladores: novosControladores,
        ),
      );
    });
  }

  void _removerCenario(CenarioSimulacao cenario) {
    setState(() => _cenarios.remove(cenario));
  }

  void _abrirModalAjusteCenario(CenarioSimulacao cenario) {
    double percentual = 0.0;
    String regraArredondamento = 'Exato (Matemático)';
    String centavosPersonalizados = '90';
    String escopoSelecionado = _categoriaSelecionada;

    final List<String> opcoesArredondamento = [
      'Exato (Matemático)',
      'Inteiro (Proteger Margem 1%)',
      'Terminar em centavos (Ex: .90)',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Ajustar ${cenario.nome}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Aplicar ajuste em:',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      value: escopoSelecionado,
                      items: _categoriasDinamicas
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c == 'Todas'
                                    ? 'Toda a Fábrica'
                                    : 'Categoria: $c',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => escopoSelecionado = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Estratégia de Preço:',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      value: regraArredondamento,
                      items: opcoesArredondamento
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => regraArredondamento = val!),
                    ),
                    const SizedBox(height: 16),
                    if (regraArredondamento ==
                        'Terminar em centavos (Ex: .90)') ...[
                      TextFormField(
                        initialValue: centavosPersonalizados,
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        decoration: const InputDecoration(
                          labelText: 'Centavos',
                          prefixText: 'R\$ X,',
                          border: OutlineInputBorder(),
                          isDense: true,
                          counterText: '',
                        ),
                        onChanged: (val) => centavosPersonalizados = val,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Percentual (%)',
                        hintText: 'Ex: 10, -5',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.percent),
                        isDense: true,
                      ),
                      onChanged: (val) => percentual =
                          double.tryParse(val.replaceAll(',', '.')) ?? 0.0,
                    ),
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
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (percentual != 0) {
                      double fator = 1 + (percentual / 100);
                      setState(() {
                        for (var prod in _produtos) {
                          if (escopoSelecionado == 'Todas' ||
                              prod['categoria'] == escopoSelecionado) {
                            double valorBase =
                                _precosPadraoIniciais[prod['id']] ?? 0.0;
                            if (valorBase > 0) {
                              double novoValor = valorBase * fator;
                              if (regraArredondamento ==
                                  'Inteiro (Proteger Margem 1%)') {
                                double valorAbaixo = novoValor.floorToDouble();
                                if (((novoValor - valorAbaixo) / novoValor) *
                                        100 >=
                                    1.0)
                                  novoValor = novoValor.ceilToDouble();
                                else
                                  novoValor = valorAbaixo;
                              } else if (regraArredondamento ==
                                  'Terminar em centavos (Ex: .90)') {
                                novoValor =
                                    novoValor.truncateToDouble() +
                                    ((int.tryParse(centavosPersonalizados) ??
                                            0) /
                                        100);
                              }
                              cenario.controladores[prod['id']]!.text =
                                  novoValor.toStringAsFixed(2);
                            }
                          }
                        }
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar Simulação'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // O Menu de Substituição Inteligente
  void _abrirMenuSubstituicao(CenarioSimulacao cenario) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sobrescrever Tabela Existente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Qual tabela você deseja atualizar com os valores desta simulação?',
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _listaTabelasOficiais.length,
                  itemBuilder: (context, index) {
                    final tab = _listaTabelasOficiais[index];
                    return ListTile(
                      leading: Icon(
                        tab['id'] == 'tabela_padrao'
                            ? Icons.star
                            : Icons.table_chart,
                        color: tab['id'] == 'tabela_padrao'
                            ? Colors.amber
                            : Colors.teal,
                      ),
                      title: Text(
                        tab['nome'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        tab['id'] == 'tabela_padrao'
                            ? 'Tabela Oficial Base (Gera Backup)'
                            : 'Tabela Derivada',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.pop(context);
                        _executarSubstituicao(cenario, tab['id'], tab['nome']);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executarSubstituicao(
    CenarioSimulacao cenario,
    String tabelaIdDestino,
    String nomeTabelaDestino,
  ) async {
    bool isPadrao = tabelaIdDestino == 'tabela_padrao';

    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              isPadrao
                  ? '⚠️ Alterar Tabela Padrão'
                  : 'Atualizar $nomeTabelaDestino',
              style: TextStyle(color: isPadrao ? Colors.red : Colors.teal),
            ),
            content: Text(
              isPadrao
                  ? 'Você está prestes a alterar os preços de toda a fábrica.\nUm backup será gerado automaticamente.'
                  : 'Isto irá esmagar os preços atuais da tabela "$nomeTabelaDestino" com os valores desta simulação. Continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPadrao ? Colors.red : Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sim, Substituir'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    setState(() => _isLoading = true);
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      DocumentReference tabelaRef = firestore
          .collection('tabelas_preco')
          .doc(tabelaIdDestino);

      // Backup só para a Tabela Padrão
      if (isPadrao) {
        String backupId = DateTime.now().toIso8601String();
        batch.set(tabelaRef.collection('backups').doc(backupId), {
          'criadoEm': FieldValue.serverTimestamp(),
          'dados': _precosPadraoIniciais,
        });
      }

      batch.set(tabelaRef, {
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (var prod in _produtos) {
        double precoSimulado =
            double.tryParse(
              cenario.controladores[prod['id']]!.text.replaceAll(',', '.'),
            ) ??
            0.0;
        if (precoSimulado > 0) {
          batch.set(tabelaRef.collection('itens').doc(prod['id']), {
            'preco': precoSimulado,
            'atualizadoEm': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$nomeTabelaDestino atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        _cenarios.remove(cenario);
        _carregarDadosGerais();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarComoNovaTabela(CenarioSimulacao cenario) async {
    String nomeNova = cenario.nome;
    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Criar Nova Tabela'),
            content: TextFormField(
              initialValue: nomeNova,
              decoration: const InputDecoration(labelText: 'Nome da Tabela'),
              onChanged: (val) => nomeNova = val,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salvar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar || nomeNova.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      DocumentReference novaTabelaRef = firestore
          .collection('tabelas_preco')
          .doc();
      batch.set(novaTabelaRef, {
        'nome': nomeNova,
        'empresa_id': widget.empresaId,
        'derivada': true,
        'ativa': true,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      for (var prod in _produtos) {
        double precoSimulado =
            double.tryParse(
              cenario.controladores[prod['id']]!.text.replaceAll(',', '.'),
            ) ??
            0.0;
        if (precoSimulado > 0)
          batch.set(novaTabelaRef.collection('itens').doc(prod['id']), {
            'preco': precoSimulado,
          });
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nova Tabela criada!'),
            backgroundColor: Colors.green,
          ),
        );
        _carregarDadosGerais();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // INTERFACE PRINCIPAL
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    var produtosFiltrados = _produtos.where((p) {
      bool atendeBusca =
          _termoBusca.isEmpty ||
          p['nome'].toLowerCase().contains(_termoBusca) ||
          p['referencia'].toLowerCase().contains(_termoBusca);
      bool atendeAba =
          _categoriaSelecionada == 'Todas' ||
          p['categoria'] == _categoriaSelecionada;
      return atendeBusca && atendeAba;
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Central de Preços'),
          backgroundColor: Colors.blueGrey.shade900,
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Tabelas Oficiais'),
              Tab(icon: Icon(Icons.science), text: 'Laboratório (Simulação)'),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.history, color: Colors.orangeAccent),
              label: const Text(
                'Backup Padrão',
                style: TextStyle(color: Colors.orangeAccent),
              ),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restauro em dev...')),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // --- FILTRO DINÂMICO ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: 'Buscar Produto...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                            onChanged: (val) =>
                                setState(() => _termoBusca = val.toLowerCase()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Categoria',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                            value: _categoriaSelecionada,
                            items: _categoriasDinamicas
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _categoriaSelecionada = val!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),

                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // =========================================================
                        // ABA 1: TABELAS OFICIAIS
                        // =========================================================
                        Column(
                          children: [
                            // 1. Selector de Tabelas com Olho Oculto
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              color: Colors.blueGrey.shade50,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _listaTabelasOficiais.map((
                                          tabela,
                                        ) {
                                          bool isAtiva =
                                              tabela['ativa'] ?? true;
                                          // Se a tabela estiver inativa e o olho não estiver ligado, desaparece
                                          if (!isAtiva && !_mostrarInativas)
                                            return const SizedBox.shrink();

                                          bool isActive =
                                              _tabelaOficialAtivaId ==
                                              tabela['id'];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8.0,
                                            ),
                                            child: ChoiceChip(
                                              label: Row(
                                                children: [
                                                  if (!isAtiva)
                                                    const Icon(
                                                      Icons.visibility_off,
                                                      size: 14,
                                                      color: Colors.redAccent,
                                                    ),
                                                  if (!isAtiva)
                                                    const SizedBox(width: 4),
                                                  Text(
                                                    tabela['nome'],
                                                    style: TextStyle(
                                                      fontWeight: isActive
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: !isAtiva
                                                          ? Colors.redAccent
                                                          : Colors.black87,
                                                      decoration: !isAtiva
                                                          ? TextDecoration
                                                                .lineThrough
                                                          : null,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              selected: isActive,
                                              selectedColor:
                                                  Colors.blueGrey.shade200,
                                              backgroundColor: !isAtiva
                                                  ? Colors.red.shade50
                                                  : Colors.white,
                                              onSelected: (selecionado) {
                                                if (selecionado)
                                                  _carregarItensTabelaOficial(
                                                    tabela['id'],
                                                  );
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _mostrarInativas
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.blueGrey,
                                    ),
                                    tooltip: 'Mostrar Tabelas Inativas',
                                    onPressed: () => setState(
                                      () =>
                                          _mostrarInativas = !_mostrarInativas,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 2. Cabeçalho
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              color: Colors.grey.shade200,
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Ref',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Produto',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Categoria',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Preço (R\$)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 3. Lista de Produtos
                            Expanded(
                              child: ListView.builder(
                                itemCount: produtosFiltrados.length,
                                itemBuilder: (context, index) {
                                  final prod = produtosFiltrados[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            prod['referencia'],
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            prod['nome'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(prod['categoria']),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: TextFormField(
                                            controller:
                                                _tab1Controladores[prod['id']],
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey,
                                            ),
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                            // 4. Rodapé (Ativar/Inativar + Gravar)
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.white,
                              child: Row(
                                children: [
                                  if (_tabelaOficialAtivaId != 'tabela_padrao')
                                    Expanded(
                                      flex: 1,
                                      child: Builder(
                                        builder: (context) {
                                          var tabAtual = _listaTabelasOficiais
                                              .firstWhere(
                                                (t) =>
                                                    t['id'] ==
                                                    _tabelaOficialAtivaId,
                                                orElse: () => {'ativa': true},
                                              );
                                          bool isAtiva = tabAtual['ativa'];
                                          return OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: isAtiva
                                                  ? Colors.red
                                                  : Colors.green,
                                              side: BorderSide(
                                                color: isAtiva
                                                    ? Colors.red
                                                    : Colors.green,
                                              ),
                                              minimumSize: const Size(
                                                double.infinity,
                                                50,
                                              ),
                                            ),
                                            icon: Icon(
                                              isAtiva
                                                  ? Icons.delete_outline
                                                  : Icons.restore,
                                            ),
                                            label: Text(
                                              isAtiva
                                                  ? 'Inativar Tabela'
                                                  : 'Reativar Tabela',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            onPressed: () =>
                                                _alternarStatusTabela(isAtiva),
                                          );
                                        },
                                      ),
                                    ),
                                  if (_tabelaOficialAtivaId != 'tabela_padrao')
                                    const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(
                                          double.infinity,
                                          50,
                                        ),
                                      ),
                                      icon: const Icon(Icons.save),
                                      label: const Text(
                                        'Gravar Valores',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: _gravarTabelaOficial,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // =========================================================
                        // ABA 2: LABORATÓRIO (COM BOTÃO DE SUBSTITUIÇÃO INTELIGENTE)
                        // =========================================================
                        SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // BLOCO FIXO: Produto e Tabela Padrão
                                  Container(
                                    width: 350,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          height: 60,
                                          color: Colors.blueGrey.shade100,
                                          child: const Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Text(
                                                    'Produto',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Text(
                                                    'Base\nPadrão',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blueGrey,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ...produtosFiltrados
                                            .map(
                                              (prod) => Container(
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    top: BorderSide(
                                                      color:
                                                          Colors.grey.shade200,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8.0,
                                                            ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Text(
                                                              prod['referencia'],
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color: Colors
                                                                        .grey,
                                                                  ),
                                                            ),
                                                            Text(
                                                              prod['nome'],
                                                              style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Container(
                                                        color: Colors
                                                            .blueGrey
                                                            .shade50,
                                                        alignment:
                                                            Alignment.center,
                                                        child: Text(
                                                          (_precosPadraoIniciais[prod['id']] ??
                                                                  0.0)
                                                              .toStringAsFixed(
                                                                2,
                                                              ),
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .blueGrey,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ],
                                    ),
                                  ),

                                  // BLOCO DINÂMICO: Cenários Gerados
                                  ..._cenarios
                                      .map(
                                        (cenario) => Container(
                                          width:
                                              140, // Ligeiramente mais largo para caber os botões
                                          margin: const EdgeInsets.only(
                                            left: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                              color: Colors.amber.shade400,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Container(
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade50,
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        top: Radius.circular(8),
                                                      ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.percent,
                                                        color: Colors
                                                            .amber
                                                            .shade900,
                                                        size: 18,
                                                      ),
                                                      onPressed: () =>
                                                          _abrirModalAjusteCenario(
                                                            cenario,
                                                          ),
                                                    ),
                                                    Expanded(
                                                      child: TextFormField(
                                                        initialValue:
                                                            cenario.nome,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                        decoration:
                                                            const InputDecoration(
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                              isDense: true,
                                                            ),
                                                        onChanged: (val) =>
                                                            cenario.nome = val,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.close,
                                                        color: Colors.redAccent,
                                                        size: 16,
                                                      ),
                                                      onPressed: () =>
                                                          _removerCenario(
                                                            cenario,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ...produtosFiltrados
                                                  .map(
                                                    (prod) => Container(
                                                      height: 50,
                                                      padding:
                                                          const EdgeInsets.all(
                                                            6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        border: Border(
                                                          top: BorderSide(
                                                            color: Colors
                                                                .grey
                                                                .shade200,
                                                          ),
                                                        ),
                                                      ),
                                                      child: TextFormField(
                                                        controller: cenario
                                                            .controladores[prod['id']],
                                                        keyboardType:
                                                            const TextInputType.numberWithOptions(
                                                              decimal: true,
                                                            ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .amber
                                                              .shade900,
                                                        ),
                                                        decoration:
                                                            const InputDecoration(
                                                              border:
                                                                  OutlineInputBorder(),
                                                              contentPadding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              isDense: true,
                                                            ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade50,
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        bottom: Radius.circular(
                                                          8,
                                                        ),
                                                      ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    ElevatedButton(
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors.teal,
                                                            foregroundColor:
                                                                Colors.white,
                                                            padding:
                                                                EdgeInsets.zero,
                                                          ),
                                                      onPressed: () =>
                                                          _salvarComoNovaTabela(
                                                            cenario,
                                                          ),
                                                      child: const Text(
                                                        'Salvar Nova',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    OutlinedButton(
                                                      style:
                                                          OutlinedButton.styleFrom(
                                                            foregroundColor:
                                                                Colors.indigo,
                                                            side:
                                                                const BorderSide(
                                                                  color: Colors
                                                                      .indigo,
                                                                ),
                                                            padding:
                                                                EdgeInsets.zero,
                                                          ),
                                                      onPressed: () =>
                                                          _abrirMenuSubstituicao(
                                                            cenario,
                                                          ),
                                                      child: const Text(
                                                        'Substituir...',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),

                                  // BLOCO DE AÇÃO: Novo Cenário
                                  Container(
                                    width: 120,
                                    margin: const EdgeInsets.only(left: 16),
                                    child: InkWell(
                                      onTap: _adicionarNovoCenario,
                                      child: Container(
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          border: Border.all(
                                            color: Colors.grey.shade400,
                                            style: BorderStyle.solid,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add,
                                              color: Colors.blueGrey,
                                              size: 20,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Simular',
                                              style: TextStyle(
                                                color: Colors.blueGrey,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
  }
}
