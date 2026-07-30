import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================================
// INJEÇÃO DO GATILHO: MOTOR DE ROTEAMENTO
// ============================================================================
import '../../widgets/smart/motor_roteamento.dart';

class TelaCadastroVendedor extends StatefulWidget {
  final String empresaId;

  const TelaCadastroVendedor({super.key, required this.empresaId});

  @override
  State<TelaCadastroVendedor> createState() => _TelaCadastroVendedorState();
}

class _TelaCadastroVendedorState extends State<TelaCadastroVendedor> {
  String _filtroStatus = 'Ativos';

  Widget _construirBotaoFiltro(String status, IconData icone) {
    bool selecionado = _filtroStatus == status;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icone,
            size: 16,
            color: selecionado ? Colors.white : Colors.blueGrey,
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: selecionado ? Colors.white : Colors.blueGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      selected: selecionado,
      selectedColor: Colors.blueGrey.shade900,
      backgroundColor: Colors.white,
      onSelected: (bool valor) {
        if (valor) setState(() => _filtroStatus = status);
      },
    );
  }

  // =========================================================================
  // MÁQUINA DE GERAR ACESSO DO VENDEDOR (MURO DE VIDRO & TROCA DE SENHA)
  // =========================================================================
  Future<void> _gerarAcessoVendedorSeguro({
    required String email,
    required String nome,
    required String whatsapp,
    required String empresaId,
    required bool isMaster,
  }) async {
    final emailTratado = email.trim().toLowerCase();
    if (emailTratado.isEmpty) return;

    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    try {
      try {
        await auth.createUserWithEmailAndPassword(
          email: emailTratado,
          password: 'NoEixo123',
        );
      } catch (e) {
        if (e is FirebaseAuthException && e.code != 'email-already-in-use') {
          rethrow;
        }
      }

      await db.collection('usuarios').doc(emailTratado).set({
        'nome': nome,
        'email': emailTratado,
        'whatsapp': whatsapp,
        'empresa_id': empresaId,
        'perfil': isMaster ? 'master' : 'vendedor',
        'modulos_permitidos': isMaster
            ? [
                'Dashboard',
                'Comercial',
                'Engenharia',
                'PCP',
                'Producao',
                'Financeiro',
                'RH',
              ]
            : ['Dashboard', 'Comercial'],
        'primeiro_acesso': true,
        'senha_acesso': 'NoEixo123',
        'ativo': true,
        'data_criacao': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Falha silenciosa ao gerar credenciais de acesso: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Equipe Comercial & Usuários'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirPainelVendedor(context, null),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Cadastrar Vendedor / Proprietário'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                const Text(
                  'Filtro Comercial:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 16),
                _construirBotaoFiltro('Ativos', Icons.check_circle_outline),
                const SizedBox(width: 8),
                _construirBotaoFiltro('Inativos', Icons.block_flipped),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('vendedores')
                  .where('empresa_id', isEqualTo: widget.empresaId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data?.docs ?? [];

                if (_filtroStatus == 'Ativos') {
                  docs = docs
                      .where(
                        (d) =>
                            (d.data() as Map<String, dynamic>)['ativo'] == true,
                      )
                      .toList();
                } else {
                  docs = docs
                      .where(
                        (d) =>
                            (d.data() as Map<String, dynamic>)['ativo'] ==
                            false,
                      )
                      .toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum profissional de vendas registrado nesta categoria.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final dados = doc.data() as Map<String, dynamic>;

                    final bool ativo = dados['ativo'] ?? true;
                    final bool global = dados['atendimento_global'] ?? false;
                    final String tipo = dados['tipo_contratacao'] == 'clt'
                        ? 'CLT'
                        : 'Autônomo';
                    final List regioes = dados['regioes_vinculadas'] ?? [];

                    return Card(
                      color: ativo ? Colors.white : Colors.grey.shade100,
                      elevation: ativo ? 2 : 0,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: global
                              ? Colors.amber.shade100
                              : (dados['tipo_contratacao'] == 'clt'
                                    ? Colors.teal.shade50
                                    : Colors.indigo.shade50),
                          child: Icon(
                            global
                                ? Icons.workspace_premium
                                : (dados['tipo_contratacao'] == 'clt'
                                      ? Icons.badge_outlined
                                      : Icons.business_center_outlined),
                            color: global
                                ? Colors.amber.shade900
                                : (dados['tipo_contratacao'] == 'clt'
                                      ? Colors.teal.shade900
                                      : Colors.indigo.shade900),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              dados['nome_vendedor'] ?? 'Sem Nome',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!global) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$tipo | ${dados['estrutura_trabalho'].toString().replaceAll('_', ' ').toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (global) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '👑 ACESSO GLOBAL (PROPRIETÁRIO)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              'Contato: ${dados['email']} | WhatsApp: ${dados['whatsapp']}',
                            ),
                            // Alterado: Remove a menção fixa a comissão
                            if (dados['tipo_contratacao'] == 'clt')
                              Text(
                                'Salário Base: R\$ ${dados['salario_base']}',
                              ),
                            const SizedBox(height: 8),
                            if (!global)
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: regioes
                                    .map(
                                      (r) => Chip(
                                        label: Text(
                                          r,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        backgroundColor:
                                            Colors.blueGrey.shade50,
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                color: Colors.blueGrey,
                                size: 28,
                              ),
                              onPressed: () =>
                                  _abrirPainelVendedor(context, doc),
                            ),
                            Switch(
                              value: ativo,
                              activeColor: Colors.teal,
                              onChanged: (v) async {
                                await FirebaseFirestore.instance
                                    .collection('vendedores')
                                    .doc(doc.id)
                                    .update({'ativo': v});
                                await MotorRoteamento.sincronizarGeral();
                              },
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
      ),
    );
  }

  void _abrirPainelVendedor(BuildContext ctx, DocumentSnapshot? docExistente) {
    final Map<String, dynamic>? dadosAlteracao =
        docExistente?.data() as Map<String, dynamic>?;

    final nomeCtrl = TextEditingController(
      text: dadosAlteracao?['nome_vendedor'],
    );
    final docCtrl = TextEditingController(
      text: dadosAlteracao?['documento_fiscal'],
    );
    final emailCtrl = TextEditingController(text: dadosAlteracao?['email']);
    final whatsCtrl = TextEditingController(text: dadosAlteracao?['whatsapp']);

    final salarioCtrl = TextEditingController(
      text: dadosAlteracao?['salario_base']?.toString() ?? '0.0',
    );

    String tipoContratacao = dadosAlteracao?['tipo_contratacao'] ?? 'clt';
    String regimeClt = dadosAlteracao?['regime_clt'] ?? 'interno';
    String estruturaTrabalho = dadosAlteracao?['estrutura_trabalho'] ?? 'solo';

    bool isAtendimentoGlobal = dadosAlteracao?['atendimento_global'] ?? false;
    bool acessoBaseCompartilhada =
        dadosAlteracao?['acesso_base_compartilhada'] ?? false;

    // NOVO: Id da política comercial
    String? politicaSelecionadaId = dadosAlteracao?['politica_comercial_id'];

    List<String> regioesSelecionadas = List<String>.from(
      dadosAlteracao?['regioes_vinculadas'] ?? [],
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                docExistente == null
                    ? '🔧 Implantar Nova Ficha de Vendedor'
                    : '📝 Atualizar Ficha Comercial',
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SEÇÃO MASTER
                      Card(
                        elevation: 0,
                        color: isAtendimentoGlobal
                            ? Colors.amber.shade50
                            : Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isAtendimentoGlobal
                                ? Colors.amber.shade400
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            '👑 ACESSO GLOBAL (Proprietário / Gestor Master)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isAtendimentoGlobal
                                  ? Colors.amber.shade900
                                  : Colors.black87,
                            ),
                          ),
                          subtitle: const Text(
                            'Libera visão de todos os clientes, ignorando regiões, e concede poderes totais ao usuário.',
                            style: TextStyle(fontSize: 12),
                          ),
                          activeColor: Colors.amber.shade700,
                          value: isAtendimentoGlobal,
                          onChanged: (val) {
                            setStateDialog(() {
                              isAtendimentoGlobal = val;
                              if (val) {
                                regioesSelecionadas.clear();
                                acessoBaseCompartilhada = true;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        '1. Regime de Contratação Têxtil',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('CLT Fixo'),
                              value: 'clt',
                              groupValue: tipoContratacao,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) =>
                                  setStateDialog(() => tipoContratacao = v!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Autônomo / PJ'),
                              value: 'autonomo',
                              groupValue: tipoContratacao,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) =>
                                  setStateDialog(() => tipoContratacao = v!),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),

                      if (tipoContratacao == 'clt') ...[
                        const Text(
                          '2. Escopo de Atuação CLT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.teal,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Interno (Televendas)'),
                                value: 'interno',
                                groupValue: regimeClt,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) =>
                                    setStateDialog(() => regimeClt = v!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Externo (Campo)'),
                                value: 'externo',
                                groupValue: regimeClt,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) =>
                                    setStateDialog(() => regimeClt = v!),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                      ],

                      const Text(
                        '3. Organização de Equipe',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.indigo,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Solo (Individual)'),
                              value: 'solo',
                              groupValue: estruturaTrabalho,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) =>
                                  setStateDialog(() => estruturaTrabalho = v!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Com Sub-Equipe'),
                              value: 'com_equipe',
                              groupValue: estruturaTrabalho,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) =>
                                  setStateDialog(() => estruturaTrabalho = v!),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 12),

                      const Text(
                        '4. Identificação Corporativa',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome Completo / Razão Social',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: docCtrl,
                        decoration: InputDecoration(
                          labelText: tipoContratacao == 'clt'
                              ? 'CPF do Vendedor'
                              : 'CNPJ da Representada',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'E-mail Comercial (LOGIN)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: whatsCtrl,
                              decoration: const InputDecoration(
                                labelText: 'WhatsApp',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone_android),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ==========================================================
                      // 5. NOVA SEÇÃO DE PARÂMETROS COMERCIAIS
                      // ==========================================================
                      const Text(
                        '5. Parâmetros Comerciais & Financeiros',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.brown,
                        ),
                      ),
                      const SizedBox(height: 12),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('politicas_comerciais')
                            .where('empresa_id', isEqualTo: widget.empresaId)
                            .where('ativo', isEqualTo: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          }
                          final politicasDocs = snapshot.data?.docs ?? [];

                          if (politicasDocs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '⚠️ Nenhuma Política Comercial cadastrada. Crie uma no Menu Financeiro primeiro.',
                              ),
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Política Comercial Vinculada',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.gavel),
                                  ),
                                  value:
                                      politicasDocs.any(
                                        (p) => p.id == politicaSelecionadaId,
                                      )
                                      ? politicaSelecionadaId
                                      : null,
                                  items: politicasDocs.map((doc) {
                                    return DropdownMenuItem<String>(
                                      value: doc.id,
                                      child: Text(doc['nome_politica']),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setStateDialog(
                                      () => politicaSelecionadaId = val,
                                    );
                                  },
                                ),
                              ),
                              if (tipoContratacao == 'clt') ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: salarioCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Salário Base (R\$)',
                                      border: OutlineInputBorder(),
                                      prefixText: 'R\$ ',
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),

                      // ESCONDE AS REGIÕES SE ELE FOR O DONO (MASTER)
                      if (!isAtendimentoGlobal) ...[
                        const SizedBox(height: 24),
                        const Text(
                          '6. Abrangência Geográfica (Territórios do Vendedor)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Card(
                          elevation: 0,
                          color: acessoBaseCompartilhada
                              ? Colors.indigo.shade50
                              : Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: acessoBaseCompartilhada
                                  ? Colors.indigo.shade200
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SwitchListTile(
                            title: const Text(
                              'Acesso à Base Compartilhada (Bolsão)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: const Text(
                              'Permite pescar clientes não mapeados ou sem dono.',
                              style: TextStyle(fontSize: 11),
                            ),
                            activeColor: Colors.indigo,
                            value: acessoBaseCompartilhada,
                            onChanged: (val) => setStateDialog(
                              () => acessoBaseCompartilhada = val,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('regioes_venda')
                              .snapshots(),
                          builder: (context, regSnapshot) {
                            if (regSnapshot.connectionState ==
                                ConnectionState.waiting)
                              return const LinearProgressIndicator();
                            final regDocs = regSnapshot.data?.docs ?? [];
                            final regAtivas = regDocs
                                .where(
                                  (doc) =>
                                      (doc.data()
                                          as Map<String, dynamic>)['ativo'] ??
                                      true,
                                )
                                .toList();

                            if (regAtivas.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.shade200,
                                  ),
                                ),
                                child: const Text(
                                  '⚠️ Nenhuma área localizada.',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: regAtivas.map((doc) {
                                  final String nomeRegiaoText =
                                      (doc.data()
                                          as Map<String, dynamic>)['nome'] ??
                                      'Sem Nome';
                                  bool selecionada = regioesSelecionadas
                                      .contains(nomeRegiaoText);

                                  return FilterChip(
                                    label: Text(
                                      nomeRegiaoText,
                                      style: TextStyle(
                                        color: selecionada
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    selected: selecionada,
                                    selectedColor: Colors.deepPurple.shade900,
                                    checkmarkColor: Colors.white,
                                    onSelected: (bool valor) {
                                      setStateDialog(() {
                                        if (valor)
                                          regioesSelecionadas.add(
                                            nomeRegiaoText,
                                          );
                                        else
                                          regioesSelecionadas.remove(
                                            nomeRegiaoText,
                                          );
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[900],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (politicaSelecionadaId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vincule uma Política Comercial!'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    final double salario =
                        double.tryParse(salarioCtrl.text) ?? 0.0;

                    final Map<String, dynamic> payload = {
                      'nome_vendedor': nomeCtrl.text.trim(),
                      'documento_fiscal': docCtrl.text.trim(),
                      'email': emailCtrl.text.trim().toLowerCase(),
                      'whatsapp': whatsCtrl.text.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      ),
                      'tipo_contratacao': tipoContratacao,
                      'regime_clt': tipoContratacao == 'clt' ? regimeClt : null,
                      'estrutura_trabalho': estruturaTrabalho,
                      'politica_comercial_id':
                          politicaSelecionadaId, // Substitui a taxa_comissao engessada
                      'salario_base': tipoContratacao == 'clt' ? salario : 0.0,
                      'regioes_vinculadas': regioesSelecionadas,
                      'atendimento_global': isAtendimentoGlobal,
                      'acesso_base_compartilhada': isAtendimentoGlobal
                          ? true
                          : acessoBaseCompartilhada,
                      'empresa_id': widget.empresaId,
                      'ativo': dadosAlteracao?['ativo'] ?? true,
                      'data_atualizacao': FieldValue.serverTimestamp(),
                    };

                    if (docExistente == null) {
                      payload['data_cadastro'] = FieldValue.serverTimestamp();
                      await FirebaseFirestore.instance
                          .collection('vendedores')
                          .add(payload);

                      if (emailCtrl.text.trim().isNotEmpty) {
                        await _gerarAcessoVendedorSeguro(
                          email: emailCtrl.text,
                          nome: nomeCtrl.text,
                          whatsapp: whatsCtrl.text,
                          empresaId: widget.empresaId,
                          isMaster: isAtendimentoGlobal,
                        );
                      }
                    } else {
                      await FirebaseFirestore.instance
                          .collection('vendedores')
                          .doc(docExistente.id)
                          .update(payload);
                    }

                    await MotorRoteamento.sincronizarGeral();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Consolidar Ficha'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
