import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tela_cadastro_empresa.dart';

class TelaDashboardAdmin extends StatefulWidget {
  const TelaDashboardAdmin({super.key});

  @override
  State<TelaDashboardAdmin> createState() => _TelaDashboardAdminState();
}

class _TelaDashboardAdminState extends State<TelaDashboardAdmin> {
  int _abaSelecionada = 0;

  final List<Map<String, dynamic>> _necessidadesClientes = [
    {
      'empresa': 'Malharia Vale do Itapocu (Exemplo)',
      'titulo': 'Relatório de Quebra de Agulhas',
      'descricao':
          'Necessitamos de um campo na produção para registrar falhas mecânicas por turno.',
      'status': 'Em Análise',
      'data': '16/05/2026',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('NoEixo Sistemas - Central SaaS'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaCadastroEmpresa()),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _abaSelecionada,
        onDestinationSelected: (idx) => setState(() => _abaSelecionada = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.business), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.forum), label: 'Necessidades'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Métricas'),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas')
            .orderBy('data_cadastro', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Erro na infraestrutura: ${snapshot.error}'),
            );
          }

          final empresasDocs = snapshot.data?.docs ?? [];

          return IndexedStack(
            index: _abaSelecionada,
            children: [
              _construirAbaClientes(empresasDocs),
              _construirAbaNecessidades(),
              _construirAbaMetricas(empresasDocs),
            ],
          );
        },
      ),
    );
  }

  // --- ABA 1: LISTAGEM E MENU DE AÇÕES DINÂMICAS ---
  Widget _construirAbaClientes(List<QueryDocumentSnapshot> documentos) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: documentos.length,
      itemBuilder: (context, index) {
        final doc = documentos[index];
        final data = doc.data() as Map<String, dynamic>;

        final String idDocumento = doc.id;
        final String nome = data['nome_fantasia'] ?? 'Sem Nome';
        final String cnpj = data['cnpj'] ?? '00.000.000/0000-00';
        final bool estaAtivo = data['ativo'] ?? false;
        final List modulos = data['modulos_ativos'] ?? [];
        final String ramo = data['ramo'] ?? 'Têxtil';
        final double faturamento = (data['faturamento_saas'] ?? 1250.0)
            .toDouble();

        return Card(
          color: estaAtivo ? Colors.white : Colors.grey[300],
          elevation: estaAtivo ? 2 : 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            // MUDANÇA DA DINÂMICA: Clicar no cartão abre a central de ações
            onTap: () => _abrirMenuAcoesCliente(idDocumento, data),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: estaAtivo
                    ? (ramo == 'Têxtil' ? Colors.blue[100] : Colors.green[100])
                    : Colors.grey[400],
                child: Icon(
                  ramo == 'Têxtil' ? Icons.texture : Icons.agriculture,
                  color: estaAtivo
                      ? (ramo == 'Têxtil'
                            ? Colors.blue[900]
                            : Colors.green[900])
                      : Colors.grey[600],
                ),
              ),
              title: Text(
                nome,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  decoration: estaAtivo
                      ? TextDecoration.none
                      : TextDecoration.lineThrough,
                  color: estaAtivo ? Colors.black : Colors.grey[700],
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('CNPJ: $cnpj'),
                  Text('Módulos Ativos: ${modulos.length}'),
                  const SizedBox(height: 8),
                  Text(
                    'Faturamento: R\$ ${faturamento.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: estaAtivo ? Colors.blueGrey : Colors.grey,
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.more_vert, color: Colors.blueGrey),
            ),
          ),
        );
      },
    );
  }

  // --- MENU INFERIOR DE GOVERNANÇA (BOTTOM SHEET) ---
  void _abrirMenuAcoesCliente(String id, Map<String, dynamic> data) {
    final nome = data['nome_fantasia'] ?? 'Empresa';
    final cnpj = data['cnpj'] ?? '';
    final ativo = data['ativo'] ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nome.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blueGrey,
                ),
              ),
              Text(
                'CNPJ: $cnpj',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const Divider(height: 30),

              // AÇÃO 1: Editar Dados
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.indigo),
                title: const Text(
                  'Editar Dados Cadastrais',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Nome, E-mail, WhatsApp, Endereço...'),
                onTap: () {
                  Navigator.pop(context);
                  _abrirFormularioEdicao(id, data);
                },
              ),

              // AÇÃO 2: Gerir Módulos Liberados
              ListTile(
                leading: const Icon(Icons.view_module, color: Colors.blue),
                title: const Text(
                  'Gerir Módulos Liberados',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Ativar ou desativar blocos do sistema'),
                onTap: () {
                  Navigator.pop(context);
                  _abrirGestaoModulos(id, data);
                },
              ),

              // AÇÃO 3: Bloquear/Ativar
              ListTile(
                leading: Icon(
                  ativo ? Icons.block : Icons.check_circle,
                  color: ativo ? Colors.red : Colors.teal,
                ),
                title: Text(
                  ativo
                      ? 'Bloquear Acesso da Empresa'
                      : 'Liberar Acesso da Empresa',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseFirestore.instance
                      .collection('empresas')
                      .doc(id)
                      .update({'ativo': !ativo});
                },
              ),

              // AÇÃO 4: WhatsApp
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: const Text(
                  'Enviar Mensagem via WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Abrindo o WhatsApp Web/App...'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- FORMULÁRIO DE EDIÇÃO GERAL (DIALOG) ---
  void _abrirFormularioEdicao(String id, Map<String, dynamic> data) {
    final nomeCtrl = TextEditingController(text: data['nome_fantasia'] ?? '');
    final razaoCtrl = TextEditingController(text: data['razao_social'] ?? '');
    final cnpjCtrl = TextEditingController(text: data['cnpj'] ?? '');
    final emailCtrl = TextEditingController(text: data['email_contato'] ?? '');
    final whatsCtrl = TextEditingController(
      text: data['whatsapp_contato'] ?? '',
    );
    final enderecoCtrl = TextEditingController(text: data['endereco'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Editar: ${data['nome_fantasia']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome Fantasia'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: razaoCtrl,
                  decoration: const InputDecoration(labelText: 'Razão Social'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cnpjCtrl,
                  decoration: const InputDecoration(labelText: 'CNPJ'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'E-mail de Contato',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: whatsCtrl,
                  decoration: const InputDecoration(labelText: 'WhatsApp'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: enderecoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Endereço Completo',
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
                backgroundColor: Colors.blueGrey[900],
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(id)
                    .update({
                      'nome_fantasia': nomeCtrl.text.trim(),
                      'razao_social': razaoCtrl.text.trim(),
                      'cnpj': cnpjCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                      'email_contato': emailCtrl.text.trim(),
                      'whatsapp_contato': whatsCtrl.text.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      ),
                      'endereco': enderecoCtrl.text.trim(),
                    });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salvar Alterações'),
            ),
          ],
        );
      },
    );
  }

  // --- FORMULÁRIO DE GESTÃO DE MÓDULOS (DIALOG) ---
  void _abrirGestaoModulos(String id, Map<String, dynamic> data) {
    List modulosAtuais = data['modulos_ativos'] ?? [];

    // Todos os módulos possíveis no sistema (Atualizado com Logística)
    final List<String> todosModulos = [
      'Dashboard',
      'Suprimentos',
      'Comercial',
      'Engenharia',
      'PCP',
      'Produção',
      'Logística', // <-- MÓDULO INJETADO AQUI
      'Financeiro',
      'RH',
    ];

    // Cria um mapa temporário para os Checkboxes
    Map<String, bool> modulosTemp = {};
    for (var mod in todosModulos) {
      modulosTemp[mod] = modulosAtuais.contains(mod);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Gerir Módulos'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: todosModulos.map((modulo) {
                    return CheckboxListTile(
                      title: Text(modulo),
                      value: modulosTemp[modulo],
                      onChanged: modulo == 'Dashboard'
                          ? null
                          : (bool? valor) {
                              setStateDialog(() {
                                modulosTemp[modulo] = valor ?? false;
                              });
                            },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    // Filtra apenas os que ficaram true
                    List<String> novosModulos = modulosTemp.entries
                        .where((e) => e.value)
                        .map((e) => e.key)
                        .toList();
                    await FirebaseFirestore.instance
                        .collection('empresas')
                        .doc(id)
                        .update({'modulos_ativos': novosModulos});
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Atualizar Acessos'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- ABA 2: MEIO DE COMUNICAÇÃO ---
  Widget _construirAbaNecessidades() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _necessidadesClientes.length,
      itemBuilder: (context, index) {
        final nec = _necessidadesClientes[index];
        final bool emAnalise = nec['status'] == 'Em Análise';

        return Card(
          color: Colors.white,
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        nec['empresa'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: emAnalise ? Colors.amber[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        nec['status'],
                        style: TextStyle(
                          color: emAnalise
                              ? Colors.amber[900]
                              : Colors.red[900],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  nec['titulo'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nec['descricao'],
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Registrado em: ${nec['data']}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.reply, size: 16),
                      label: const Text('Responder Empresa'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- ABA 3: PARTICIPAÇÃO DE FATURAMENTO DINÂMICA ---
  Widget _construirAbaMetricas(List<QueryDocumentSnapshot> documentos) {
    double faturamentoTotal = 0;
    double faturamentoTextil = 0;

    for (var doc in documentos) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['ativo'] == true) {
        double valor = (data['faturamento_saas'] ?? 1250.0).toDouble();
        String ramo = data['ramo'] ?? 'Têxtil';

        faturamentoTotal += valor;
        if (ramo == 'Têxtil') faturamentoTextil += valor;
      }
    }

    double participacaoTextil = faturamentoTotal > 0
        ? (faturamentoTextil / faturamentoTotal) * 100
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SAÚDE FINANCEIRA DO ECOSSISTEMA SAAS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _cardMetricaMestre(
                  'Faturamento Ativo',
                  'R\$ ${faturamentoTotal.toStringAsFixed(2)}',
                  Icons.monetization_on,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _cardMetricaMestre(
                  'Divisão Têxtil',
                  'R\$ ${faturamentoTextil.toStringAsFixed(2)}',
                  Icons.texture,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Participação do Setor Têxtil na NoEixo Sistemas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: faturamentoTotal > 0
                        ? (participacaoTextil / 100)
                        : 0.0,
                    backgroundColor: Colors.grey[200],
                    color: Colors.blue[700],
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Segmento Têxtil: ${participacaoTextil.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      Text(
                        'Outros Módulos: ${(100 - participacaoTextil).toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardMetricaMestre(
    String titulo,
    String valor,
    IconData icone,
    Color cor,
  ) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: cor.withOpacity(0.1),
              child: Icon(icone, color: cor),
            ),
            const SizedBox(height: 16),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
