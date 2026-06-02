import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaArvoreCatalogo extends StatefulWidget {
  const TelaArvoreCatalogo({super.key});

  @override
  State<TelaArvoreCatalogo> createState() => _TelaArvoreCatalogoState();
}

class _TelaArvoreCatalogoState extends State<TelaArvoreCatalogo> {
  List<Map<String, dynamic>> _atributosDisponiveis = [];
  bool _carregandoAtributos = true;

  // CONTROLO DE ACESSO: Definido como true para libertar o seu acesso imediato.
  // Em produção, isto lerá o perfil do utilizador logado (Ex: user.role == 'admin')
  final bool _isAdmin = true;

  @override
  void initState() {
    super.initState();
    _carregarAtributosBase();
  }

  Future<void> _carregarAtributosBase() async {
    List<Map<String, dynamic>> lista = [
      {'id': 'cores', 'nome': 'Cores'},
      {'id': 'grades', 'nome': 'Grades (Tamanhos)'},
      {'id': 'unidades', 'nome': 'Unidades de Medida'},
      {'id': 'tecidos', 'nome': 'Tecidos / Malhas'},
    ];

    try {
      var customSnap = await FirebaseFirestore.instance
          .collection('tabelas_auxiliares_config')
          .where('clienteId', isEqualTo: 'teste_textil')
          .where('ativo', isEqualTo: true)
          .get();

      for (var doc in customSnap.docs) {
        lista.add({'id': doc.id, 'nome': doc['titulo']});
      }

      if (mounted) {
        setState(() {
          _atributosDisponiveis = lista;
          _carregandoAtributos = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _carregandoAtributos = false);
    }
  }

  Future<void> _injetarClassesPadrao() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final db = FirebaseFirestore.instance;
    WriteBatch batch = db.batch();

    List<Map<String, String>> padroes = [
      {'classe': 'ATIVO IMOBILIZADO', 'subclasse': 'MÁQUINAS E EQUIPAMENTOS'},
      {'classe': 'CONSUMO INDUSTRIAL', 'subclasse': 'MANUTENÇÃO FABRIL'},
      {
        'classe': 'DESPESAS ADMINISTRATIVAS',
        'subclasse': 'MATERIAL DE ESCRITÓRIO',
      },
      {'classe': 'INSUMOS DE PRODUÇÃO', 'subclasse': 'FIOS E MALHAS'},
      {'classe': 'INSUMOS DE PRODUÇÃO', 'subclasse': 'AVIAMENTOS'},
    ];

    for (var p in padroes) {
      DocumentReference doc = db.collection('arvore_catalogo').doc();
      batch.set(doc, {
        'clienteId': 'teste_textil',
        'classe': p['classe'],
        'subclasse': p['subclasse'],
        'subSubclasse': 'GERAL',
        'atributosExigidos': [],
        'ativo': true,
        'dataCriacao': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estrutura Básica Carregada!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // =========================================================================
  // GESTÃO EM LOTE (LÁPIS DE EDIÇÃO NOS 3 NÍVEIS)
  // =========================================================================
  Future<void> _editarNomeNivel(
    String nivel,
    String nomeAntigo, {
    String? classePai,
  }) async {
    final ctrl = TextEditingController(text: nomeAntigo);
    String titulo = nivel == 'classe'
        ? 'Renomear Classe'
        : 'Renomear Subclasse';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          titulo,
          style: const TextStyle(
            color: Colors.indigo,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Isto reestruturará automaticamente o nome em todas as categorias deste galho.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              String novoNome = ctrl.text.trim().toUpperCase();
              if (novoNome.isNotEmpty && novoNome != nomeAntigo) {
                WriteBatch batch = FirebaseFirestore.instance.batch();
                Query query = FirebaseFirestore.instance
                    .collection('arvore_catalogo')
                    .where('clienteId', isEqualTo: 'teste_textil');

                if (nivel == 'classe') {
                  query = query.where('classe', isEqualTo: nomeAntigo);
                } else if (nivel == 'subclasse') {
                  query = query
                      .where('classe', isEqualTo: classePai)
                      .where('subclasse', isEqualTo: nomeAntigo);
                }

                var snap = await query.get();
                for (var doc in snap.docs) {
                  batch.update(doc.reference, {
                    nivel: novoNome,
                    'dataAtualizacao': FieldValue.serverTimestamp(),
                  });
                }

                await batch.commit();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('SALVAR ALTERAÇÃO'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pedirNovoNomeManual(String titulo) async {
    final ctrl = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          titulo,
          style: const TextStyle(
            color: Colors.indigo,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Nome do item...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                Navigator.pop(context, ctrl.text.trim().toUpperCase()),
            child: const Text('ADICIONAR'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MOTOR DE CRIAÇÃO DINÂMICA DE TABELAS AUXILIARES ("NA MOSCA")
  // =========================================================================
  Future<void> _criarNovaTabelaAuxiliarNaMosca(
    StateSetter setDialogState,
    Function(String) aoCriarTabela,
  ) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Nova Tabela Auxiliar',
          style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Ex: Tipos de Botão, Furos...',
            labelText: 'Nome da Tabela',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              String nomeTabela = ctrl.text.trim();
              if (nomeTabela.isNotEmpty) {
                try {
                  // 1. Grava no banco de dados na coleção de tabelas customizadas
                  var docRef = await FirebaseFirestore.instance
                      .collection('tabelas_auxiliares_config')
                      .add({
                        'clienteId': 'teste_textil',
                        'titulo': nomeTabela,
                        'ativo': true,
                        'dataCriacao': FieldValue.serverTimestamp(),
                      });

                  // 2. Atualiza a lista da tela principal
                  setState(() {
                    _atributosDisponiveis.add({
                      'id': docRef.id,
                      'nome': nomeTabela,
                    });
                  });

                  // 3. Atualiza o StateBuilder do Modal e seleciona o item criado
                  setDialogState(() {});
                  aoCriarTabela(docRef.id);

                  if (mounted) {
                    Navigator.pop(context); // Fecha o dialog de criar tabela
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tabela "$nomeTabela" pronta para uso!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('CRIAR TABELA'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // EDIÇÃO DE REGRAS E MULTI-CAMPOS DA FOLHA SELECIONADA
  // =========================================================================
  void _abrirDialogoEdicaoFolha(Map<String, dynamic> folha) {
    final nomeCtrl = TextEditingController(text: folha['subSubclasse']);
    List<String> atributosSelecionados = List<String>.from(
      folha['atributosExigidos'] ?? [],
    );
    String? atributoParaAdicionar;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Editar Categoria / Regras',
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Caminho: ${folha['classe']} > ${folha['subclasse']}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nome da Folha (Nível 3)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const Divider(height: 30),
                      const Text(
                        'Campos / Tabelas Auxiliares Exigidas:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('Selecione a tabela...'),
                              value: atributoParaAdicionar,
                              items: _atributosDisponiveis
                                  .where(
                                    (a) => !atributosSelecionados.contains(
                                      a['id'],
                                    ),
                                  )
                                  .map(
                                    (a) => DropdownMenuItem<String>(
                                      value: a['id'],
                                      child: Text(a['nome']),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) => setDialogState(
                                () => atributoParaAdicionar = val,
                              ),
                            ),
                          ),
                          // BOTÃO DE CRIAÇÃO NA MOSCA INJETADO AQUI
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.green,
                            ),
                            tooltip: 'Criar nova tabela base',
                            onPressed: () => _criarNovaTabelaAuxiliarNaMosca(
                              setDialogState,
                              (novaTabelaId) {
                                setDialogState(
                                  () => atributoParaAdicionar = novaTabelaId,
                                );
                              },
                            ),
                          ),
                          TextButton.icon(
                            onPressed: atributoParaAdicionar == null
                                ? null
                                : () {
                                    setDialogState(() {
                                      atributosSelecionados.add(
                                        atributoParaAdicionar!,
                                      );
                                      atributoParaAdicionar = null;
                                    });
                                  },
                            icon: const Icon(Icons.add_link),
                            label: const Text('Atrelar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: atributosSelecionados.map((attrId) {
                          String nomeAttr = _atributosDisponiveis.firstWhere(
                            (e) => e['id'] == attrId,
                            orElse: () => {'nome': attrId},
                          )['nome'];
                          return Chip(
                            label: Text(
                              nomeAttr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: Colors.indigo.shade50,
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setDialogState(
                              () => atributosSelecionados.remove(attrId),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    String novoNome = nomeCtrl.text.trim().toUpperCase();
                    if (novoNome.isEmpty) return;

                    await FirebaseFirestore.instance
                        .collection('arvore_catalogo')
                        .doc(folha['id'])
                        .update({
                          'subSubclasse': novoNome,
                          'atributosExigidos': atributosSelecionados,
                          'dataAtualizacao': FieldValue.serverTimestamp(),
                        });
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('SALVAR ALTERAÇÕES'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // CRIAÇÃO E CLONAGEM DE MOLDE
  // =========================================================================
  void _abrirDialogoNovaFolha(
    Map<String, Map<String, List<String>>> hierarquiaCompleta, {
    String? initialClasse,
    String? initialSubclasse,
    List<String>? initialAtributos,
  }) {
    List<String> classesExistentes = hierarquiaCompleta.keys.toList()..sort();

    String? classeSel =
        initialClasse ??
        (classesExistentes.isNotEmpty ? classesExistentes.first : null);
    List<String> subclassesExistentes = classeSel != null
        ? (hierarquiaCompleta[classeSel]?.keys.toList() ?? [])
        : [];
    String? subclasseSel =
        initialSubclasse ??
        (subclassesExistentes.isNotEmpty ? subclassesExistentes.first : null);

    List<String> folhasExistentes = (classeSel != null && subclasseSel != null)
        ? (hierarquiaCompleta[classeSel]![subclasseSel] ?? [])
        : [];
    String? folhaSel;

    List<String> atributosSelecionados = initialAtributos != null
        ? List<String>.from(initialAtributos)
        : [];
    String? atributoParaAdicionar;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                initialClasse != null
                    ? 'Clonar Molde / Regras'
                    : 'Configurador de Categoria',
                style: const TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Classe (O Tronco)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              value: classesExistentes.contains(classeSel)
                                  ? classeSel
                                  : null,
                              hint: Text(
                                classesExistentes.isEmpty
                                    ? 'Vazio. Use o botão + 👉'
                                    : 'Selecione...',
                                style: TextStyle(
                                  color: classesExistentes.isEmpty
                                      ? Colors.red
                                      : Colors.black87,
                                ),
                              ),
                              items: classesExistentes.isEmpty
                                  ? null
                                  : classesExistentes
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c),
                                          ),
                                        )
                                        .toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  classeSel = val;
                                  subclassesExistentes =
                                      hierarquiaCompleta[classeSel]?.keys
                                          .toList() ??
                                      [];
                                  subclasseSel = subclassesExistentes.isNotEmpty
                                      ? subclassesExistentes.first
                                      : null;
                                  folhasExistentes =
                                      (classeSel != null &&
                                          subclasseSel != null)
                                      ? (hierarquiaCompleta[classeSel]![subclasseSel] ??
                                            [])
                                      : [];
                                  folhaSel = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              String? nova = await _pedirNovoNomeManual(
                                'Nova Classe Principal',
                              );
                              if (nova != null && nova.isNotEmpty)
                                setDialogState(() {
                                  if (!classesExistentes.contains(nova))
                                    classesExistentes.add(nova);
                                  classeSel = nova;
                                  subclassesExistentes = [];
                                  subclasseSel = null;
                                  folhasExistentes = [];
                                  folhaSel = null;
                                });
                            },
                            icon: const Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        '2. Subclasse (A Gaveta)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              value: subclassesExistentes.contains(subclasseSel)
                                  ? subclasseSel
                                  : null,
                              hint: Text(
                                subclassesExistentes.isEmpty
                                    ? 'Vazio. Use o botão + 👉'
                                    : 'Selecione...',
                                style: TextStyle(
                                  color: subclassesExistentes.isEmpty
                                      ? Colors.red
                                      : Colors.black87,
                                ),
                              ),
                              items: subclassesExistentes.isEmpty
                                  ? null
                                  : subclassesExistentes
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c),
                                          ),
                                        )
                                        .toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  subclasseSel = val;
                                  folhasExistentes =
                                      (classeSel != null &&
                                          subclasseSel != null)
                                      ? (hierarquiaCompleta[classeSel]![subclasseSel] ??
                                            [])
                                      : [];
                                  folhaSel = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              String? nova = await _pedirNovoNomeManual(
                                'Nova Subclasse',
                              );
                              if (nova != null && nova.isNotEmpty)
                                setDialogState(() {
                                  if (!subclassesExistentes.contains(nova))
                                    subclassesExistentes.add(nova);
                                  subclasseSel = nova;
                                  folhasExistentes = [];
                                  folhaSel = null;
                                });
                            },
                            icon: const Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        '3. Folha Específica',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              value: folhasExistentes.contains(folhaSel)
                                  ? folhaSel
                                  : null,
                              hint: Text(
                                folhasExistentes.isEmpty
                                    ? 'Vazio. Use o botão + 👉'
                                    : 'Selecione ou crie...',
                                style: TextStyle(
                                  color: folhasExistentes.isEmpty
                                      ? Colors.red
                                      : Colors.black87,
                                ),
                              ),
                              items: folhasExistentes.isEmpty
                                  ? null
                                  : folhasExistentes
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c),
                                          ),
                                        )
                                        .toList(),
                              onChanged: (val) =>
                                  setDialogState(() => folhaSel = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              String? nova = await _pedirNovoNomeManual(
                                'Nova Folha (Ex: Malhas, Etiquetas)',
                              );
                              if (nova != null && nova.isNotEmpty)
                                setDialogState(() {
                                  if (!folhasExistentes.contains(nova))
                                    folhasExistentes.add(nova);
                                  folhaSel = nova;
                                });
                            },
                            icon: const Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                      const Divider(height: 30),

                      const Text(
                        'Campos / Tabelas Auxiliares Exigidas:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('Selecione a tabela...'),
                              value: atributoParaAdicionar,
                              items: _atributosDisponiveis
                                  .where(
                                    (a) => !atributosSelecionados.contains(
                                      a['id'],
                                    ),
                                  )
                                  .map(
                                    (a) => DropdownMenuItem<String>(
                                      value: a['id'],
                                      child: Text(a['nome']),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) => setDialogState(
                                () => atributoParaAdicionar = val,
                              ),
                            ),
                          ),
                          // BOTÃO DE CRIAÇÃO NA MOSCA INJETADO AQUI TAMBÉM
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.green,
                            ),
                            tooltip: 'Criar nova tabela base',
                            onPressed: () => _criarNovaTabelaAuxiliarNaMosca(
                              setDialogState,
                              (novaTabelaId) {
                                setDialogState(
                                  () => atributoParaAdicionar = novaTabelaId,
                                );
                              },
                            ),
                          ),
                          TextButton.icon(
                            onPressed: atributoParaAdicionar == null
                                ? null
                                : () {
                                    setDialogState(() {
                                      atributosSelecionados.add(
                                        atributoParaAdicionar!,
                                      );
                                      atributoParaAdicionar = null;
                                    });
                                  },
                            icon: const Icon(Icons.add_link),
                            label: const Text('Atrelar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: atributosSelecionados.map((attrId) {
                          String nomeAttr = _atributosDisponiveis.firstWhere(
                            (e) => e['id'] == attrId,
                            orElse: () => {'nome': attrId},
                          )['nome'];
                          return Chip(
                            label: Text(
                              nomeAttr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: Colors.indigo.shade50,
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setDialogState(
                              () => atributosSelecionados.remove(attrId),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (classeSel == null ||
                        subclasseSel == null ||
                        folhaSel == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Preencha os 3 níveis para salvar!'),
                        ),
                      );
                      return;
                    }

                    var query = await FirebaseFirestore.instance
                        .collection('arvore_catalogo')
                        .where('clienteId', isEqualTo: 'teste_textil')
                        .where('subSubclasse', isEqualTo: folhaSel)
                        .get();

                    if (query.docs.isNotEmpty) {
                      await query.docs.first.reference.update({
                        'atributosExigidos': atributosSelecionados,
                      });
                    } else {
                      await FirebaseFirestore.instance
                          .collection('arvore_catalogo')
                          .add({
                            'clienteId': 'teste_textil',
                            'classe': classeSel,
                            'subclasse': subclasseSel,
                            'subSubclasse': folhaSel,
                            'atributosExigidos': atributosSelecionados,
                            'ativo': true,
                            'dataCriacao': FieldValue.serverTimestamp(),
                          });
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('SALVAR REGRAS'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // O DRAWABLE DO MANUAL DE ENGENHARIA (CONHECIMENTO GESTOR EXCLUSIVO)
  // =========================================================================
  Widget _buildDrawerManual() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.indigo,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.engineering, color: Colors.white, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'MANUAL GESTOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Engenharia de Processos ERP',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('1. O Molde vs. O Dado Real'),
                  _bodyText(
                    'A Árvore de Catálogo representa exclusivamente a regra invisível (A Fôrma). Ela não guarda cores ou larguras; guarda o que cada material exige.',
                  ),
                  _alertText(
                    'Erro Crítico a Evitar: Nunca crie variantes como nome de Folha (Ex: "Meia Malha Rosa"). Isso destruiria a inteligência e os relatórios do sistema.',
                  ),

                  const Divider(height: 30),
                  _sectionTitle('2. Os 4 Pilares da Estrutura Têxtil'),

                  _bulletPoint(
                    '🧵 Folha A: O FIO',
                    'Matéria-prima raiz em bobinas. Exige Fiação (30/1, 24/1) e Tipo de Fibra. É o ponto de partida do consumo.',
                  ),
                  _bulletPoint(
                    '◽ Folha B: MALHA CRUA',
                    'Tecido recém-saído do tear, sem cor. Exige Estrutura (Meia Malha, Moletom) e Gramatura Bruta.',
                  ),
                  _bulletPoint(
                    '🎨 Folha C: MALHA TINGIDA',
                    'Material pronto para a mesa de corte. Exige Estrutura, Cor Exata (Tabela Base) e Gramatura Acabada.',
                  ),
                  _bulletPoint(
                    '🌀 Folha D: MALHA ESTAMPADA',
                    'Tecido com desenhos contínuos. Exige Estrutura, Cor de Fundo e Código da Estampa.',
                  ),

                  const Divider(height: 30),
                  _sectionTitle('3. Manutenção e Lote'),
                  _bodyText(
                    'A Trava de Unicidade impede folhas duplicadas em gavetas diferentes. Caso erre a digitação de uma Classe inteira, clique no Lápis do cabeçalho. O Firebase executará um Batch Update alterando centenas de registos vinculados em menos de um segundo.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.indigo,
      ),
    ),
  );
  Widget _bodyText(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
    ),
  );
  Widget _alertText(String text) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Colors.red.shade900,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  Widget _bulletPoint(String title, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.blueGrey,
          ),
        ),
        Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    ),
  );

  // =========================================================================
  // INTERFACE PRINCIPAL
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      endDrawer: _isAdmin
          ? _buildDrawerManual()
          : null, // Aciona o painel se for Admin
      appBar: AppBar(
        title: const Text(
          'Árvore de Categorias',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(
                Icons.help_outline,
                size: 24,
                color: Colors.amber,
              ),
              tooltip: 'Manual de Engenharia de Processos',
              onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('arvore_catalogo')
            .where('clienteId', isEqualTo: 'teste_textil')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          Map<String, Map<String, List<Map<String, dynamic>>>> arvore = {};
          Map<String, Map<String, List<String>>> hierarquiaPura = {};

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              String classe = data['classe'] ?? 'SEM CLASSE';
              String subclasse = data['subclasse'] ?? 'SEM SUBCLASSE';
              String folha = data['subSubclasse'] ?? 'GERAL';

              if (!arvore.containsKey(classe)) arvore[classe] = {};
              if (!arvore[classe]!.containsKey(subclasse))
                arvore[classe]![subclasse] = [];
              arvore[classe]![subclasse]!.add(data);

              if (!hierarquiaPura.containsKey(classe))
                hierarquiaPura[classe] = {};
              if (!hierarquiaPura[classe]!.containsKey(subclasse))
                hierarquiaPura[classe]![subclasse] = [];
              if (!hierarquiaPura[classe]![subclasse]!.contains(folha))
                hierarquiaPura[classe]![subclasse]!.add(folha);
            }
          }

          if (arvore.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_tree,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'A sua Árvore de Categorias está vazia.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text(
                        'CARREGAR ESTRUTURA PADRÃO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: _injetarClassesPadrao,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: arvore.keys.map((nomeClasse) {
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.account_tree, color: Colors.indigo),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          nomeClasse,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.indigo,
                        ),
                        onPressed: () => _editarNomeNivel('classe', nomeClasse),
                      ),
                    ],
                  ),
                  children: arvore[nomeClasse]!.keys.map((nomeSubclasse) {
                    return ExpansionTile(
                      leading: const Icon(
                        Icons.subdirectory_arrow_right,
                        color: Colors.blueGrey,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              nomeSubclasse,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.blueGrey,
                            ),
                            onPressed: () => _editarNomeNivel(
                              'subclasse',
                              nomeSubclasse,
                              classePai: nomeClasse,
                            ),
                          ),
                        ],
                      ),
                      children: arvore[nomeClasse]![nomeSubclasse]!.map((
                        folha,
                      ) {
                        List<dynamic> attrs = folha['atributosExigidos'] ?? [];
                        return ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 56,
                            right: 16,
                          ),
                          title: Text(
                            folha['subSubclasse'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            attrs.isEmpty
                                ? 'Sem tabelas atreladas'
                                : 'Exige: ${attrs.length} campo(s) base',
                          ),
                          trailing: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.copy,
                                  size: 18,
                                  color: Colors.blue,
                                ),
                                tooltip: 'Clonar Molde',
                                onPressed: () {
                                  _abrirDialogoNovaFolha(
                                    hierarquiaPura,
                                    initialClasse: folha['classe'],
                                    initialSubclasse: folha['subclasse'],
                                    initialAtributos: List<String>.from(attrs),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                tooltip: 'Editar Regras',
                                onPressed: () =>
                                    _abrirDialogoEdicaoFolha(folha),
                              ),
                              Switch(
                                value: folha['ativo'] ?? true,
                                activeColor: Colors.indigo,
                                onChanged: (valor) => FirebaseFirestore.instance
                                    .collection('arvore_catalogo')
                                    .doc(folha['id'])
                                    .update({'ativo': valor}),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('arvore_catalogo')
            .where('clienteId', isEqualTo: 'teste_textil')
            .snapshots(),
        builder: (context, snapshot) {
          Map<String, Map<String, List<String>>> hierarquia = {};
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              String c = doc['classe'];
              String s = doc['subclasse'];
              String f = doc['subSubclasse'];
              if (!hierarquia.containsKey(c)) hierarquia[c] = {};
              if (!hierarquia[c]!.containsKey(s)) hierarquia[c]![s] = [];
              if (!hierarquia[c]![s]!.contains(f)) hierarquia[c]![s]!.add(f);
            }
          }
          return FloatingActionButton.extended(
            backgroundColor: Colors.indigo,
            onPressed: () => _abrirDialogoNovaFolha(hierarquia),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Plantar Novo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}
