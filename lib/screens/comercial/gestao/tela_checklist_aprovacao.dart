import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TelaChecklistAprovacao extends StatefulWidget {
  // NOVO: Adicionado o recebimento do ID da empresa
  final String empresaId;
  final String pedidoId;
  final String clienteNome;
  final double valorPedido;
  final String tipoAprovacao; // 'Comercial', 'PCP', ou 'Financeiro'

  const TelaChecklistAprovacao({
    super.key,
    required this.empresaId, // NOVO
    required this.pedidoId,
    required this.clienteNome,
    required this.valorPedido,
    required this.tipoAprovacao,
  });

  @override
  State<TelaChecklistAprovacao> createState() => _TelaChecklistAprovacaoState();
}

class _TelaChecklistAprovacaoState extends State<TelaChecklistAprovacao> {
  final _formatadorMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  Map<String, String> _respostasBinarias = {};
  Map<String, TextEditingController> _respostasTexto = {};

  final TextEditingController _mensagemDevolucaoCtrl = TextEditingController();

  bool _carregandoPerguntas = true;
  bool _processandoVeredito = false;
  List<DocumentSnapshot> _perguntasConfiguradas = [];

  String _vereditoFinal = 'APROVADO';

  @override
  void initState() {
    super.initState();
    _buscarRegrasDoChecklist();
  }

  @override
  void dispose() {
    _respostasTexto.forEach((key, controller) => controller.dispose());
    _mensagemDevolucaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarRegrasDoChecklist() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('checklist_config')
          // CORREÇÃO: Chave padronizada e valor dinâmico via widget.empresaId
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('setor', isEqualTo: widget.tipoAprovacao)
          .where('ativo', isEqualTo: true)
          .get();

      setState(() {
        _perguntasConfiguradas = snap.docs;
        for (var doc in _perguntasConfiguradas) {
          _respostasTexto[doc.id] = TextEditingController();
        }
        _carregandoPerguntas = false;
      });
    } catch (e) {
      if (mounted) setState(() => _carregandoPerguntas = false);
    }
  }

  bool _validarRespostas() {
    for (var doc in _perguntasConfiguradas) {
      var data = doc.data() as Map<String, dynamic>;
      String tipo = data['tipo_resposta'] ?? 'BINARIA';
      String id = doc.id;

      if (tipo == 'BINARIA') {
        if (!_respostasBinarias.containsKey(id)) {
          _mostrarErro('Responda à pergunta: "${data['pergunta']}"');
          return false;
        }
      } else if (tipo == 'CONDICIONAL') {
        if (!_respostasBinarias.containsKey(id)) {
          _mostrarErro('Responda à pergunta: "${data['pergunta']}"');
          return false;
        }
        String respostaEscolhida = _respostasBinarias[id]!;
        String condicaoExigencia = data['exige_justificativa_se'] ?? 'NAO';

        if (respostaEscolhida == condicaoExigencia &&
            _respostasTexto[id]!.text.trim().isEmpty) {
          _mostrarErro(
            'A justificativa é obrigatória para a pergunta: "${data['pergunta']}"',
          );
          return false;
        }
      } else if (tipo == 'TEXTO') {
        if (_respostasTexto[id]!.text.trim().isEmpty) {
          _mostrarErro('Preencha o campo de texto: "${data['pergunta']}"');
          return false;
        }
      }
    }

    if (_vereditoFinal == 'DEVOLVIDO' &&
        _mensagemDevolucaoCtrl.text.trim().isEmpty) {
      _mostrarErro(
        'Você deve escrever uma instrução para o vendedor realizar o ajuste.',
      );
      return false;
    }

    return true;
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _finalizarAvaliacao() async {
    if (!_validarRespostas()) return;

    setState(() => _processandoVeredito = true);

    try {
      final db = FirebaseFirestore.instance;
      final emailAvaliador =
          FirebaseAuth.instance.currentUser?.email ?? 'Gestor Desconhecido';

      List<Map<String, dynamic>> historicoRespostas = [];
      for (var doc in _perguntasConfiguradas) {
        var data = doc.data() as Map<String, dynamic>;
        String id = doc.id;
        historicoRespostas.add({
          'pergunta': data['pergunta'],
          'tipo': data['tipo_resposta'],
          'resposta_binaria': _respostasBinarias[id],
          'justificativa_texto': _respostasTexto[id]!.text.trim(),
        });
      }

      await db
          .collection('pedidos_venda')
          .doc(widget.pedidoId)
          .collection('avaliacoes_historico')
          .add({
            'setor': widget.tipoAprovacao,
            'avaliador': emailAvaliador,
            'data_avaliacao': FieldValue.serverTimestamp(),
            'veredito': _vereditoFinal,
            'respostas': historicoRespostas,
          });

      String chaveStatus = '';
      String statusNovo = '';

      if (widget.tipoAprovacao == 'Comercial') {
        chaveStatus = 'status_comercial';
        statusNovo = _vereditoFinal == 'APROVADO' ? 'Aprovado' : 'Devolvido';
      } else if (widget.tipoAprovacao == 'PCP') {
        chaveStatus = 'status_pcp';
        statusNovo = _vereditoFinal == 'APROVADO' ? 'Aprovado' : 'Devolvido';
      } else if (widget.tipoAprovacao == 'Financeiro') {
        chaveStatus = 'status_financeiro';
        statusNovo = _vereditoFinal == 'APROVADO' ? 'Aprovado' : 'Rejeitado';
      }

      Map<String, dynamic> updateData = {chaveStatus: statusNovo};

      if (widget.tipoAprovacao == 'Comercial' && _vereditoFinal == 'APROVADO') {
        updateData['status_pcp'] = 'Em Análise';
        updateData['status_financeiro'] = 'Em Análise';
      }

      if (_vereditoFinal == 'DEVOLVIDO') {
        updateData['historico_mensagens'] = FieldValue.arrayUnion([
          {
            'data': Timestamp.now(),
            'autor': emailAvaliador,
            'mensagem': _mensagemDevolucaoCtrl.text.trim(),
            'tipo': 'GESTOR_PARA_VENDEDOR',
          },
        ]);
      }

      await db
          .collection('pedidos_venda')
          .doc(widget.pedidoId)
          .update(updateData);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avaliação concluída com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processandoVeredito = false);
        _mostrarErro('Erro ao processar: $e');
      }
    }
  }

  Widget _construirPergunta(DocumentSnapshot doc, int index) {
    var data = doc.data() as Map<String, dynamic>;
    String tipo = data['tipo_resposta'] ?? 'BINARIA';
    String id = doc.id;

    bool mostrarCaixaTexto = false;
    if (tipo == 'TEXTO') {
      mostrarCaixaTexto = true;
    } else if (tipo == 'CONDICIONAL') {
      String condicao = data['exige_justificativa_se'] ?? 'NAO';
      if (_respostasBinarias[id] == condicao) mostrarCaixaTexto = true;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.indigo.shade50,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data['pergunta'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            if (tipo == 'BINARIA' || tipo == 'CONDICIONAL') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          setState(() => _respostasBinarias[id] = 'SIM'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _respostasBinarias[id] == 'SIM'
                              ? Colors.green
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _respostasBinarias[id] == 'SIM'
                                ? Colors.green.shade700
                                : Colors.grey.shade300,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'SIM',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _respostasBinarias[id] == 'SIM'
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          setState(() => _respostasBinarias[id] = 'NAO'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _respostasBinarias[id] == 'NAO'
                              ? Colors.red
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _respostasBinarias[id] == 'NAO'
                                ? Colors.red.shade700
                                : Colors.grey.shade300,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'NÃO',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _respostasBinarias[id] == 'NAO'
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (mostrarCaixaTexto) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _respostasTexto[id],
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: tipo == 'TEXTO'
                      ? 'Descreva aqui'
                      : 'Justificativa Obrigatória',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.amber.shade50,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color corSetor = Colors.indigo;
    if (widget.tipoAprovacao == 'PCP') corSetor = Colors.orange.shade800;
    if (widget.tipoAprovacao == 'Financeiro') corSetor = Colors.teal.shade700;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Avaliação: ${widget.tipoAprovacao}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: corSetor,
        foregroundColor: Colors.white,
      ),
      body: _carregandoPerguntas
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cliente',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            widget.clienteNome,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Valor Total',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            _formatadorMoeda.format(widget.valorPedido),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: corSetor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                Expanded(
                  child: _perguntasConfiguradas.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhuma regra configurada para este setor.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _perguntasConfiguradas.length,
                          itemBuilder: (context, index) {
                            return _construirPergunta(
                              _perguntasConfiguradas[index],
                              index,
                            );
                          },
                        ),
                ),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Decisão Final:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text(
                                  'APROVAR',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                value: 'APROVADO',
                                groupValue: _vereditoFinal,
                                activeColor: Colors.green,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) =>
                                    setState(() => _vereditoFinal = val!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(
                                  widget.tipoAprovacao == 'Financeiro'
                                      ? 'REPROVAR'
                                      : 'DEVOLVER P/ AJUSTE',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                value: 'DEVOLVIDO',
                                groupValue: _vereditoFinal,
                                activeColor: Colors.red,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) =>
                                    setState(() => _vereditoFinal = val!),
                              ),
                            ),
                          ],
                        ),
                        if (_vereditoFinal == 'DEVOLVIDO') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _mensagemDevolucaoCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText:
                                  'Instrução para o Vendedor (Obrigatório)',
                              hintText:
                                  'Ex: Negocie o prazo para o dia 20 ou altere a condição de pagamento...',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.red.shade50,
                              prefixIcon: const Icon(
                                Icons.message,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _vereditoFinal == 'APROVADO'
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _processandoVeredito
                                ? null
                                : _finalizarAvaliacao,
                            child: _processandoVeredito
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'GRAVAR ${_vereditoFinal} NO SISTEMA',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
