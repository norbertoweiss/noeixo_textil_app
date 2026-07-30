import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaConfiguracaoChecklist extends StatefulWidget {
  // NOVO: Adicionado o recebimento do ID da empresa
  final String empresaId;
  final String setorAcesso;

  const TelaConfiguracaoChecklist({
    super.key,
    required this.empresaId, // NOVO
    required this.setorAcesso,
  });

  @override
  State<TelaConfiguracaoChecklist> createState() =>
      _TelaConfiguracaoChecklistState();
}

class _TelaConfiguracaoChecklistState extends State<TelaConfiguracaoChecklist> {
  final List<String> _setores = ['Comercial', 'PCP', 'Financeiro'];

  final String _tipoBinaria = 'BINARIA';
  final String _tipoCondicional = 'CONDICIONAL';
  final String _tipoTexto = 'TEXTO';

  void _abrirDialogoPergunta({
    DocumentSnapshot? docParaEditar,
    required String setorFixo,
  }) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController _perguntaCtrl = TextEditingController();

    String _tipoSelecionado = _tipoBinaria;
    String _condicaoJustificativa = 'NAO';
    bool _salvando = false;

    if (docParaEditar != null) {
      final data = docParaEditar.data() as Map<String, dynamic>;
      _perguntaCtrl.text = data['pergunta'] ?? '';
      _tipoSelecionado = data['tipo_resposta'] ?? _tipoBinaria;
      _condicaoJustificativa = data['exige_justificativa_se'] ?? 'NAO';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                docParaEditar == null
                    ? 'Nova Pergunta - $setorFixo'
                    : 'Editar Pergunta',
                style: const TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _perguntaCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Pergunta ou Instrução',
                            hintText:
                                'Ex: O cliente possui limite de crédito disponível?',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Campo obrigatório'
                              : null,
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Comportamento da Pergunta (Parâmetro):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                title: const Text(
                                  'Binária Simples (Apenas botões SIM / NÃO)',
                                ),
                                value: _tipoBinaria,
                                groupValue: _tipoSelecionado,
                                activeColor: Colors.indigo,
                                onChanged: (val) => setDialogState(
                                  () => _tipoSelecionado = val!,
                                ),
                              ),
                              RadioListTile<String>(
                                title: const Text(
                                  'Condicional (Exige texto dependendo da resposta)',
                                ),
                                value: _tipoCondicional,
                                groupValue: _tipoSelecionado,
                                activeColor: Colors.indigo,
                                onChanged: (val) => setDialogState(
                                  () => _tipoSelecionado = val!,
                                ),
                              ),
                              RadioListTile<String>(
                                title: const Text(
                                  'Texto Livre (Apenas campo para digitação)',
                                ),
                                value: _tipoTexto,
                                groupValue: _tipoSelecionado,
                                activeColor: Colors.indigo,
                                onChanged: (val) => setDialogState(
                                  () => _tipoSelecionado = val!,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_tipoSelecionado == _tipoCondicional) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              border: Border.all(color: Colors.amber.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Tornar a justificativa obrigatória quando a resposta for:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text(
                                          'SIM',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        value: 'SIM',
                                        groupValue: _condicaoJustificativa,
                                        activeColor: Colors.green,
                                        onChanged: (val) => setDialogState(
                                          () => _condicaoJustificativa = val!,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text(
                                          'NÃO',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        value: 'NAO',
                                        groupValue: _condicaoJustificativa,
                                        activeColor: Colors.red,
                                        onChanged: (val) => setDialogState(
                                          () => _condicaoJustificativa = val!,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _salvando
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setDialogState(() => _salvando = true);

                            try {
                              // CORREÇÃO: Utilizando a chave 'empresa_id' e o widget.empresaId
                              final dados = {
                                'empresa_id': widget.empresaId,
                                'setor': setorFixo,
                                'pergunta': _perguntaCtrl.text.trim(),
                                'tipo_resposta': _tipoSelecionado,
                                'exige_justificativa_se':
                                    _tipoSelecionado == _tipoCondicional
                                    ? _condicaoJustificativa
                                    : null,
                                'ativo': true,
                                'dataAtualizacao': FieldValue.serverTimestamp(),
                              };

                              if (docParaEditar == null) {
                                dados['dataCriacao'] =
                                    FieldValue.serverTimestamp();
                                await FirebaseFirestore.instance
                                    .collection('checklist_config')
                                    .add(dados);
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('checklist_config')
                                    .doc(docParaEditar.id)
                                    .update(dados);
                              }

                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              setDialogState(() => _salvando = false);
                            }
                          }
                        },
                  child: _salvando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Salvar Parâmetro'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _alterarStatusPergunta(String docId, bool novoStatus) async {
    await FirebaseFirestore.instance
        .collection('checklist_config')
        .doc(docId)
        .update({'ativo': novoStatus});
  }

  Widget _construirListaPerguntas(String setorFixo) {
    bool temPermissao =
        widget.setorAcesso == setorFixo || widget.setorAcesso == 'Admin';

    return Column(
      children: [
        if (!temPermissao)
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.visibility, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Modo Visualização. Apenas a equipe do setor $setorFixo pode adicionar ou editar regras.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('checklist_config')
                // CORREÇÃO: Chave padronizada e valor dinâmico via widget.empresaId
                .where('empresa_id', isEqualTo: widget.empresaId)
                .where('setor', isEqualTo: setorFixo)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.playlist_add_check,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma regra configurada para o setor $setorFixo.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              var perguntas = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: perguntas.length,
                itemBuilder: (context, index) {
                  var doc = perguntas[index];
                  var data = doc.data() as Map<String, dynamic>;
                  bool ativo = data['ativo'] ?? true;
                  String tipo = data['tipo_resposta'] ?? _tipoBinaria;

                  String descTipo = 'Sim / Não (Simples)';
                  IconData iconeTipo = Icons.toggle_on;
                  Color corTipo = Colors.blueGrey;

                  if (tipo == _tipoCondicional) {
                    String cond = data['exige_justificativa_se'] == 'SIM'
                        ? 'SIM'
                        : 'NÃO';
                    descTipo = 'Condicional (Exige texto se responder $cond)';
                    iconeTipo = Icons.rule;
                    corTipo = Colors.orange.shade700;
                  } else if (tipo == _tipoTexto) {
                    descTipo = 'Campo de Texto Livre';
                    iconeTipo = Icons.short_text;
                    corTipo = Colors.teal;
                  }

                  return Card(
                    color: ativo ? Colors.white : Colors.grey.shade100,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: ativo
                            ? Colors.grey.shade300
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: ativo
                            ? corTipo.withOpacity(0.1)
                            : Colors.grey.shade200,
                        child: Icon(
                          iconeTipo,
                          color: ativo ? corTipo : Colors.grey,
                        ),
                      ),
                      title: Text(
                        data['pergunta'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ativo ? Colors.black87 : Colors.grey,
                          decoration: ativo
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Text(
                        descTipo,
                        style: TextStyle(
                          color: ativo ? corTipo : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: temPermissao
                                  ? Colors.blueGrey
                                  : Colors.grey.shade300,
                            ),
                            tooltip: temPermissao
                                ? 'Editar Pergunta'
                                : 'Acesso Negado',
                            onPressed: temPermissao
                                ? () => _abrirDialogoPergunta(
                                    docParaEditar: doc,
                                    setorFixo: setorFixo,
                                  )
                                : null,
                          ),
                          Switch(
                            value: ativo,
                            activeColor: Colors.indigo,
                            onChanged: temPermissao
                                ? (val) => _alterarStatusPergunta(doc.id, val)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    int abaInicial = 0;
    if (widget.setorAcesso == 'PCP') abaInicial = 1;
    if (widget.setorAcesso == 'Financeiro') abaInicial = 2;

    return DefaultTabController(
      length: _setores.length,
      initialIndex: abaInicial,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'Construtor de Checklists',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.indigo.shade900,
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.orangeAccent,
            indicatorWeight: 4,
            tabs: _setores
                .map((setor) => Tab(text: setor.toUpperCase()))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: _setores
              .map((setor) => _construirListaPerguntas(setor))
              .toList(),
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton.extended(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task),
              label: const Text(
                'NOVA PERGUNTA',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                int indexAba = DefaultTabController.of(context).index;
                String setorAtivo = _setores[indexAba];

                if (widget.setorAcesso != setorAtivo &&
                    widget.setorAcesso != 'Admin') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Acesso Negado: Apenas o setor $setorAtivo pode criar regras nesta aba.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                _abrirDialogoPergunta(setorFixo: setorAtivo);
              },
            );
          },
        ),
      ),
    );
  }
}
