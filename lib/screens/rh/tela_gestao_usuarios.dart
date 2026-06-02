import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaGestaoUsuarios extends StatefulWidget {
  final String empresaId;
  final List<String> modulosEmpresa;

  const TelaGestaoUsuarios({
    super.key,
    required this.empresaId,
    required this.modulosEmpresa,
  });

  @override
  State<TelaGestaoUsuarios> createState() => _TelaGestaoUsuariosState();
}

class _TelaGestaoUsuariosState extends State<TelaGestaoUsuarios> {
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
              fontSize: 13,
            ),
          ),
        ],
      ),
      selected: selecionado,
      selectedColor: Colors.blueGrey.shade900,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selecionado ? Colors.transparent : Colors.grey.shade300,
      ),
      showCheckmark: false,
      onSelected: (bool valor) {
        if (valor) {
          setState(() => _filtroStatus = status);
        }
      },
    );
  }

  // ==========================================
  // ABA 1: GESTÃO E LISTAGEM DE COLABORADORES
  // ==========================================
  Widget _construirAbaColaboradores(List<DocumentSnapshot> listaFuncoes) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: listaFuncoes.isEmpty
            ? () => _mostrarAvisoCriarFuncaoPrimeiro()
            : () => _abrirPainelNovoColaborador(listaFuncoes),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo Colaborador'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                const Text(
                  'Filtrar Equipe:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                _construirBotaoFiltro('Ativos', Icons.check_circle_outline),
                const SizedBox(width: 8),
                _construirBotaoFiltro('Inativos', Icons.block_flipped),
                const SizedBox(width: 8),
                _construirBotaoFiltro('Todos', Icons.group_outlined),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .where('empresa_id', isEqualTo: widget.empresaId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rawDocs = snapshot.data?.docs ?? [];

                var colaboradores = rawDocs.where((doc) {
                  final dados = doc.data() as Map<String, dynamic>;
                  return dados['perfil'] != 'admin_noeixo';
                }).toList();

                if (_filtroStatus == 'Ativos') {
                  colaboradores = colaboradores.where((doc) {
                    final dados = doc.data() as Map<String, dynamic>;
                    return (dados['grid_status_ativo'] ??
                            dados['ativo'] ??
                            true) ==
                        true;
                  }).toList();
                } else if (_filtroStatus == 'Inativos') {
                  colaboradores = colaboradores.where((doc) {
                    final dados = doc.data() as Map<String, dynamic>;
                    return (dados['grid_status_ativo'] ??
                            dados['ativo'] ??
                            true) ==
                        false;
                  }).toList();
                }

                if (colaboradores.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        'Nenhum colaborador localizado com o filtro: "$_filtroStatus".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: colaboradores.length,
                  itemBuilder: (context, index) {
                    final userDoc = colaboradores[index];
                    final dados = userDoc.data() as Map<String, dynamic>;

                    final String cargo = dados['perfil_nivel'] ?? 'Operador';
                    final List modulosHerdados =
                        dados['modulos_permitidos'] ?? [];
                    final bool statusAtivo =
                        dados['grid_status_ativo'] ?? dados['ativo'] ?? true;
                    final bool travaAtiva =
                        dados['trava_modificacao_salva'] ?? false;

                    return Card(
                      color: statusAtivo ? Colors.white : Colors.grey.shade200,
                      elevation: statusAtivo ? 2 : 0,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: statusAtivo
                            ? BorderSide.none
                            : BorderSide(color: Colors.grey.shade300),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: statusAtivo
                              ? Colors.blueGrey.shade100
                              : Colors.grey.shade300,
                          child: Icon(
                            Icons.person,
                            color: statusAtivo
                                ? Colors.blueGrey.shade900
                                : Colors.grey.shade600,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              dados['nome'] ?? 'Sem nome',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: statusAtivo
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                                decoration: statusAtivo
                                    ? TextDecoration.none
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusAtivo
                                    ? Colors.indigo.shade50
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                cargo,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusAtivo
                                      ? Colors.indigo.shade900
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            if (!statusAtivo) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'INATIVO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Login: ${dados['email']}',
                              style: TextStyle(
                                color: statusAtivo
                                    ? Colors.black54
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              children: modulosHerdados
                                  .map(
                                    (m) => Chip(
                                      label: Text(
                                        m,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      padding: EdgeInsets.zero,
                                      backgroundColor: statusAtivo
                                          ? Colors.grey.shade100
                                          : Colors.grey.shade300,
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
                              icon: Icon(
                                Icons.edit_note_rounded,
                                color: statusAtivo
                                    ? Colors.blueGrey
                                    : Colors.grey,
                                size: 30,
                              ),
                              onPressed: () => _abrirPainelEditarColaborador(
                                userDoc,
                                listaFuncoes,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: statusAtivo,
                              activeColor: Colors.teal,
                              onChanged: (bool novoStatus) async {
                                await FirebaseFirestore.instance
                                    .collection('usuarios')
                                    .doc(userDoc.id)
                                    .update({
                                      'grid_status_ativo': novoStatus,
                                      'ativo': novoStatus,
                                    });
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

  void _mostrarAvisoCriarFuncaoPrimeiro() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '⚠️ Alerta de Sistema: Cadastre uma Função Operacional na Aba 2 antes de vincular sua equipe.',
        ),
        backgroundColor: Colors.amber,
      ),
    );
  }

  void _abrirPainelNovoColaborador(List<DocumentSnapshot> funcoesDisponiveis) {
    final nomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final whatsCtrl = TextEditingController();

    var funcaoSelecionadaDoc = funcoesDisponiveis.first;
    final Map<String, dynamic> primeiroCargoData =
        funcaoSelecionadaDoc.data() as Map<String, dynamic>;
    String cargoSelecionadoTexto =
        primeiroCargoData['nome_funcao'] ?? 'Operador';
    bool travaEdicaoSalva = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Cadastrar Colaborador na Unidade'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome Completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'E-mail Corporativo',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: whatsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp',
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Selecione a Função Organizacional',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: cargoSelecionadoTexto,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: funcoesDisponiveis.map((f) {
                        final d = f.data() as Map<String, dynamic>;
                        final String nomeDaFuncao =
                            d['nome_funcao'] ?? 'Operador';
                        return DropdownMenuItem(
                          value: nomeDaFuncao,
                          child: Text(nomeDaFuncao),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setStateDialog(() {
                          cargoSelecionadoTexto = v!;
                          funcaoSelecionadaDoc = funcoesDisponiveis.firstWhere(
                            (element) =>
                                (element.data()
                                    as Map<String, dynamic>)['nome_funcao'] ==
                                v,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    SwitchListTile(
                      title: const Text(
                        'Travar registros após salvar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Impossibilita alteração de dados sem autorização do gestor.',
                      ),
                      value: travaEdicaoSalva,
                      activeColor: Colors.indigo,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) =>
                          setStateDialog(() => travaEdicaoSalva = v),
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
                    backgroundColor: Colors.blueGrey[900],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final email = emailCtrl.text.trim().toLowerCase();

                    // TRAVA DE SEGURANÇA: Bloqueia palavras avulsas como "babaca"
                    final bool emailValido = RegExp(
                      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                    ).hasMatch(email);
                    if (!emailValido) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '❌ Formato de e-mail inválido. O login deve terminar em @dominio.com',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    final dadosFuncao =
                        funcaoSelecionadaDoc.data() as Map<String, dynamic>;
                    List<dynamic> modulosHerdados =
                        dadosFuncao['modulos_permitidos'] ?? ['Dashboard'];

                    await FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(email)
                        .set({
                          'nome': nomeCtrl.text.trim(),
                          'email': email,
                          'whatsapp': whatsCtrl.text.replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          ),
                          'empresa_id': widget.empresaId,
                          'perfil_nivel': cargoSelecionadoTexto,
                          'perfil':
                              cargoSelecionadoTexto.toLowerCase() == 'master'
                              ? 'master'
                              : 'operador',
                          'modulos_permitidos': modulosHerdados,
                          'trava_modificacao_salva': travaEdicaoSalva,
                          'senha_acesso': 'NoEixo123',
                          'primeiro_acesso': true,
                          'grid_status_ativo': true,
                          'ativo': true,
                          'data_criacao': FieldValue.serverTimestamp(),
                        });

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Salvar Colaborador'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // INTERFACE DE EDIÇÃO TOTALMENTE DESTRAVADA E IMUNE A FALHAS DE ASSERÇÃO NO WEB
  void _abrirPainelEditarColaborador(
    DocumentSnapshot userDoc,
    List<DocumentSnapshot> funcoesDisponiveis,
  ) {
    final dadosUser = userDoc.data() as Map<String, dynamic>;

    final nomeCtrl = TextEditingController(text: dadosUser['nome'] ?? '');
    final whatsCtrl = TextEditingController(text: dadosUser['whatsapp'] ?? '');
    final String emailMestre = userDoc.id;

    String cargoAtual = dadosUser['perfil_nivel'] ?? 'Operador';
    bool travaEdicaoSalva = dadosUser['trava_modificacao_salva'] ?? true;

    // Constrói uma lista de Strings puras contendo os cargos criados na Aba 2
    List<String> opcoesDeCargosTexto = funcoesDisponiveis
        .map((f) {
          final d = f.data() as Map<String, dynamic>;
          return (d['nome_funcao'] ?? '').toString();
        })
        .where((nome) => nome.isNotEmpty)
        .toList();

    // SEGURANÇA UX: Se o cargo atual do banco não estiver na lista da Aba 2, nós o injetamos para evitar falha de renderização
    if (!opcoesDeCargosTexto.contains(cargoAtual)) {
      opcoesDeCargosTexto.insert(0, cargoAtual);
    }

    String cargoSelecionadoInstancia = cargoAtual;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                'Editar Dados: ${dadosUser['nome'] ?? 'Colaborador'}',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Colaborador',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: whatsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp Corporativo',
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Alterar Função Organizacional (Cadeira)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // DROPDOWN SEGURO BASEADO EM STRINGS COMPATÍVEIS
                    DropdownButtonFormField<String>(
                      value: cargoSelecionadoInstancia,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: opcoesDeCargosTexto.map((String cargoNome) {
                        return DropdownMenuItem<String>(
                          value: cargoNome,
                          child: Text(cargoNome),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setStateDialog(() {
                          cargoSelecionadoInstancia = v!;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    SwitchListTile(
                      title: const Text(
                        'Travar registros após salvar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Bloqueia alterações sem autorização da gerência.',
                      ),
                      value: travaEdicaoSalva,
                      activeColor: Colors.indigo,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) =>
                          setStateDialog(() => travaEdicaoSalva = v),
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
                    backgroundColor: Colors.blueGrey[900],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    // Localiza a carteira de módulos atrelada a essa função de destino
                    List<dynamic> novosModulosHerdados = ['Dashboard'];

                    final matchFuncao = funcoesDisponiveis.where((f) {
                      final d = f.data() as Map<String, dynamic>;
                      return d['nome_funcao'] == cargoSelecionadoInstancia;
                    });

                    if (matchFuncao.isNotEmpty) {
                      final dadosDaFuncaoMatch =
                          matchFuncao.first.data() as Map<String, dynamic>;
                      novosModulosHerdados =
                          dadosDaFuncaoMatch['modulos_permitidos'] ??
                          ['Dashboard'];
                    } else if (dadosUser.containsKey('modulos_permitidos')) {
                      // Preserva os acessos antigos se for um cargo legado digitado manualmente
                      novosModulosHerdados = dadosUser['modulos_permitidos'];
                    }

                    await FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(emailMestre)
                        .update({
                          'nome': nomeCtrl.text.trim(),
                          'whatsapp': whatsCtrl.text.replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          ),
                          'perfil_nivel': cargoSelecionadoInstancia,
                          'perfil':
                              cargoSelecionadoInstancia.toLowerCase() ==
                                  'master'
                              ? 'master'
                              : 'operador',
                          'modulos_permitidos': novosModulosHerdados,
                          'trava_modificacao_salva': travaEdicaoSalva,
                        });

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Atualizar Cadastro'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // ABA 2: MODELAGEM DE FUNÇÕES E PERMISSÕES
  // ==========================================
  Widget _construirAbaFuncoes() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirPainelNovaFuncao,
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_moderator),
        label: const Text('Nova Função (Cargo)'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('funcoes')
            .where('empresa_id', isEqualTo: widget.empresaId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final funcoes = snapshot.data?.docs ?? [];

          if (funcoes.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma função customizada cadastrada nesta indústria.\nCrie cargos como "Enfestador" ou "Estoquista" abaixo.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: funcoes.length,
            itemBuilder: (context, index) {
              final dados = funcoes[index].data() as Map<String, dynamic>;
              final List modulos = dados['modulos_permitidos'] ?? [];

              return Card(
                color: Colors.white,
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    child: Icon(
                      Icons.architecture,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  title: Text(
                    dados['nome_funcao'] ?? 'Sem nome',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      const Text(
                        'Módulos Vinculados a esta Cadeira:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: modulos
                            .map(
                              (m) => Chip(
                                label: Text(
                                  m,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('funcoes')
                          .doc(funcoes[index].id)
                          .delete();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _abrirPainelNovaFuncao() {
    final nomeFuncaoCtrl = TextEditingController();
    Map<String, bool> modulosSelecao = {};
    for (var mod in widget.modulosEmpresa) {
      if (mod != 'Dashboard') modulosSelecao[mod] = false;
    }
    modulosSelecao['Minha Equipe'] = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Modelar Nova Função Industrial'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nomeFuncaoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Cargo / Função',
                        hintText: 'Ex: Supervisor de Tecelagem',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Vincular Módulos e Privilégios de Comando',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: modulosSelecao.keys.map((modulo) {
                          return CheckboxListTile(
                            title: Text(
                              modulo,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: modulo == 'Minha Equipe'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: modulo == 'Minha Equipe'
                                    ? Colors.indigo
                                    : Colors.black87,
                              ),
                            ),
                            value: modulosSelecao[modulo],
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) => setStateDialog(
                              () => modulosSelecao[modulo] = v!,
                            ),
                          );
                        }).toList(),
                      ),
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
                    backgroundColor: Colors.indigo.shade900,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final String nomeCargo = nomeFuncaoCtrl.text.trim();
                    if (nomeCargo.isEmpty) return;

                    List<String> modulosPermitidos = ['Dashboard'];
                    modulosSelecao.forEach((mod, ativo) {
                      if (ativo) modulosPermitidos.add(mod);
                    });

                    await FirebaseFirestore.instance.collection('funcoes').add({
                      'nome_funcao': nomeCargo,
                      'empresa_id': widget.empresaId,
                      'modulos_permitidos': modulosPermitidos,
                      'data_cadastro': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Salvar Regra de Cargo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('funcoes')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .snapshots(),
      builder: (context, funcoesSnapshot) {
        final listaFuncoes = funcoesSnapshot.data?.docs ?? [];

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                color: Colors.white,
                child: const TabBar(
                  labelColor: Colors.blueGrey,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blueGrey,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.badge_outlined),
                      text: "1. Lista de Colaboradores",
                    ),
                    Tab(
                      icon: Icon(Icons.assignment_ind_outlined),
                      text: "2. Funções & Permissões",
                    ),
                  ],
                ),
              ),
            ),
            body: TabBarView(
              children: [
                _construirAbaColaboradores(listaFuncoes),
                _construirAbaFuncoes(),
              ],
            ),
          ),
        );
      },
    );
  }
}
