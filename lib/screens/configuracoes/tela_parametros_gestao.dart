import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaParametrosGestao extends StatefulWidget {
  final String empresaId;

  const TelaParametrosGestao({super.key, required this.empresaId});

  @override
  State<TelaParametrosGestao> createState() => _TelaParametrosGestaoState();
}

class _TelaParametrosGestaoState extends State<TelaParametrosGestao> {
  String? _tabelaSelecionada;
  final TextEditingController _novoItemController = TextEditingController();
  bool _salvando = false;

  // ==========================================================================
  // MODAL PARA CRIAR NOVA TABELA (CATEGORIA)
  // ==========================================================================
  void _abrirDialogNovaTabela() {
    TextEditingController nomeTabelaController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Nova Tabela de Gestão',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nomeTabelaController,
          decoration: const InputDecoration(
            labelText: 'Nome da Tabela (Ex: Motivos de Inativação)',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (nomeTabelaController.text.trim().isNotEmpty) {
                setState(() {
                  _tabelaSelecionada = nomeTabelaController.text
                      .trim()
                      .toUpperCase();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Criar Tabela'),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SALVAR NOVO ITEM NO BANCO DE DADOS
  // ==========================================================================
  Future<void> _salvarNovoItem() async {
    if (_tabelaSelecionada == null || _tabelaSelecionada!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crie ou selecione uma tabela primeiro!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String texto = _novoItemController.text.trim();
    if (texto.isEmpty) return;

    setState(() => _salvando = true);

    try {
      // Coleção renomeada para refletir o escopo global do ERP
      await FirebaseFirestore.instance.collection('parametros_gestao').add({
        'empresa_id': widget.empresaId,
        'tipo': _tabelaSelecionada,
        'descricao': texto.toUpperCase(),
        'criado_em': FieldValue.serverTimestamp(),
      });

      _novoItemController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item salvo com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluirItem(String docId) async {
    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir Parâmetro?'),
            content: const Text(
              'Este item deixará de aparecer nas opções do sistema.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Excluir',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmar) {
      await FirebaseFirestore.instance
          .collection('parametros_gestao')
          .doc(docId)
          .delete();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parametros_gestao')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .snapshots(),
      builder: (context, snapshot) {
        List<DocumentSnapshot> docs = snapshot.hasData
            ? snapshot.data!.docs
            : [];

        List<String> tabelasDb = docs
            .map(
              (d) =>
                  (d.data() as Map<String, dynamic>)['tipo'] as String? ?? '',
            )
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList();
        tabelasDb.sort();

        if (_tabelaSelecionada != null &&
            !tabelasDb.contains(_tabelaSelecionada)) {
          tabelasDb.add(_tabelaSelecionada!);
          tabelasDb.sort();
        }

        if (_tabelaSelecionada == null && tabelasDb.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _tabelaSelecionada = tabelasDb.first);
          });
        }

        List<DocumentSnapshot> itensDaTabela = docs.where((d) {
          return (d.data() as Map<String, dynamic>)['tipo'] ==
              _tabelaSelecionada;
        }).toList();

        itensDaTabela.sort(
          (a, b) => ((a.data() as Map<String, dynamic>)['descricao'] ?? '')
              .compareTo((b.data() as Map<String, dynamic>)['descricao'] ?? ''),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Máquina de Parâmetros de Gestão'),
            backgroundColor: Colors.blueGrey.shade800,
            foregroundColor: Colors.white,
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.grey.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tabela Selecionada',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: const Text(
                                    'Crie sua primeira tabela...',
                                  ),
                                  value: tabelasDb.contains(_tabelaSelecionada)
                                      ? _tabelaSelecionada
                                      : null,
                                  items: tabelasDb.map((tabela) {
                                    return DropdownMenuItem(
                                      value: tabela,
                                      child: Text(tabela),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(() => _tabelaSelecionada = val);
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Criar Nova Tabela',
                            child: ElevatedButton(
                              onPressed: _abrirDialogNovaTabela,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Icon(Icons.add),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      if (_tabelaSelecionada != null) ...[
                        Text(
                          'Adicionar item em "$_tabelaSelecionada"',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _novoItemController,
                          decoration: const InputDecoration(
                            labelText: 'Descrição do Novo Item',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.playlist_add),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          onFieldSubmitted: (_) => _salvarNovoItem(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _salvando ? null : _salvarNovoItem,
                            icon: _salvando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: const Text(
                              'SALVAR ITEM',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey.shade800,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const VerticalDivider(width: 1, thickness: 1),

              Expanded(
                flex: 2,
                child: _tabelaSelecionada == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.table_chart_outlined,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhuma tabela de gestão encontrada.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Clique no botão "+" à esquerda para criar a sua primeira tabela.',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : itensDaTabela.isEmpty
                    ? Center(
                        child: Text(
                          'Tabela vazia. Adicione o primeiro item na coluna ao lado!',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: itensDaTabela.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          var doc = itensDaTabela[index];
                          var data = doc.data() as Map<String, dynamic>;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueGrey.shade50,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.blueGrey.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              data['descricao'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _excluirItem(doc.id),
                              tooltip: 'Excluir Item',
                            ),
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
}
