import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tela_ficha_tecnica_main.dart';
import 'form_processo.dart'; // Para permitir criar novos processos na hora

class AbaProcessos extends StatefulWidget {
  final TelaFichaTecnicaMainState controller;

  const AbaProcessos({super.key, required this.controller});

  @override
  State<AbaProcessos> createState() => _AbaProcessosState();
}

class _AbaProcessosState extends State<AbaProcessos> {
  bool _carregandoBase = true;
  List<Map<String, dynamic>> _processosBaseList = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosBase();
  }

  Future<void> _carregarDadosBase() async {
    setState(() => _carregandoBase = true);
    try {
      final processosSnap = await FirebaseFirestore.instance
          .collection('processos_engenharia')
          .get();

      setState(() {
        _processosBaseList = processosSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _carregandoBase = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar base de processos: $e')),
        );
      }
      setState(() => _carregandoBase = false);
    }
  }

  void _modalAdicionarProcesso() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecione uma Operação'),
        content: SizedBox(
          width: double.maxFinite,
          child: _processosBaseList.isEmpty
              ? const Text(
                  'Nenhuma operação cadastrada no banco de dados da Engenharia.\nClique no botão abaixo para criar a primeira!',
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _processosBaseList.length,
                  itemBuilder: (context, index) {
                    final procBase = _processosBaseList[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.precision_manufacturing,
                          color: Colors.teal,
                        ),
                        title: Text(procBase['nome'] ?? ''),
                        subtitle: Text(
                          '${procBase['maquinaNome'] ?? ''} - ${procBase['setorNome'] ?? ''}',
                        ),
                        trailing: const Icon(
                          Icons.add_circle,
                          color: Colors.teal,
                        ),
                        onTap: () {
                          setState(() {
                            widget.controller.processosRoteiro.add({
                              'id': procBase['id'],
                              'nome': procBase['nome'],
                              'maquinaId': procBase['maquinaId'],
                              'maquinaNome': procBase['maquinaNome'],
                              'setorId': procBase['setorId'],
                              'setorNome': procBase['setorNome'],
                              'tipo': procBase['tipo'],
                              'tempoMinutos': procBase['tempoMinutos'] ?? 0.0,
                              'custoExterno': procBase['custoExterno'] ?? 0.0,
                              'ativo': true,
                              'observacao': '',
                            });
                          });
                          widget.controller.registrarAlteracao();
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Criar Nova na Base'),
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FormProcesso()),
              );
              _carregarDadosBase(); // Recarrega após voltar
            },
          ),
        ],
      ),
    );
  }

  void _modalEditarProcessoRoteiro(int index) {
    final proc = widget.controller.processosRoteiro[index];
    bool isAtivo = proc['ativo'] ?? true;
    TextEditingController obsCtrl = TextEditingController(
      text: proc['observacao'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Editar: ${proc['nome']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'As alterações feitas aqui afetam apenas o roteiro desta Ficha Técnica.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  'Operação Ativa neste Lote?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isAtivo
                      ? 'Sim, o PCP vai gerar OP para esta etapa.'
                      : 'Não, será ignorada (rasurada).',
                  style: TextStyle(color: isAtivo ? Colors.teal : Colors.red),
                ),
                value: isAtivo,
                activeColor: Colors.teal,
                onChanged: (val) => setModalState(() => isAtivo = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: obsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observação para Produção (Opcional)',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: Costurar com cuidado extra',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  widget.controller.processosRoteiro[index]['ativo'] = isAtivo;
                  widget.controller.processosRoteiro[index]['observacao'] =
                      obsCtrl.text;
                });
                widget.controller.registrarAlteracao();
                Navigator.pop(context);
              },
              child: const Text('Salvar Localmente'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoBase) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: _modalAdicionarProcesso,
            icon: const Icon(Icons.add_task),
            label: const Text(
              'Adicionar Operação ao Roteiro',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        if (widget.controller.processosRoteiro.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              "Arraste (≡) para reordenar. O Lápis edita e inativa a operação para esta peça.",
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
        Expanded(
          child: widget.controller.processosRoteiro.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma operação adicionada.\nClique no botão acima para montar o roteiro.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: widget.controller.processosRoteiro.length,
                  onReorder: (int oldIndex, int newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = widget.controller.processosRoteiro.removeAt(
                        oldIndex,
                      );
                      widget.controller.processosRoteiro.insert(newIndex, item);
                    });
                    widget.controller.registrarAlteracao();
                  },
                  itemBuilder: (context, index) {
                    final proc = widget.controller.processosRoteiro[index];
                    bool ativo = proc['ativo'] ?? true;
                    return Card(
                      key: ValueKey(
                        '${proc['id']}_$index',
                      ), // Key essencial para o Reorderable
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      elevation: ativo ? 2 : 0,
                      color: ativo ? Colors.white : Colors.grey.shade200,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ativo
                              ? Colors.teal.shade50
                              : Colors.grey.shade300,
                          child: Text(
                            '${index + 1}º',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ativo ? Colors.teal : Colors.grey,
                            ),
                          ),
                        ),
                        title: Text(
                          proc['nome'] ?? 'Operação Desconhecida',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: ativo
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                            color: ativo ? Colors.black : Colors.grey,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Máquina: ${proc['maquinaNome'] ?? '-'} | Setor: ${proc['setorNome'] ?? '-'}',
                            ),
                            if (proc['observacao'] != null &&
                                proc['observacao'].toString().isNotEmpty)
                              Text(
                                'Obs: ${proc['observacao']}',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.orange,
                                ),
                              ),
                            if (!ativo)
                              const Text(
                                'INATIVO PARA ESTA REFERÊNCIA',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blueGrey,
                              ),
                              onPressed: () =>
                                  _modalEditarProcessoRoteiro(index),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.controller.processosRoteiro.removeAt(
                                    index,
                                  );
                                });
                                widget.controller.registrarAlteracao();
                              },
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.drag_handle, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
