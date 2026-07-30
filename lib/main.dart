import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';

import 'screens/cadastros_base/tela_cadastros_base.dart';
import 'screens/cadastros_base/tela_parametros_qualidade.dart';
import 'screens/fornecedores/tela_fornecedores.dart';
import 'screens/insumos/tela_abas_suprimentos.dart';
import 'screens/estoque/tela_entrada_conferencia.dart';
import 'screens/estoque/tela_estoque_materia_prima.dart';
import 'screens/financeiro/tela_financeiro_menu.dart';
import 'screens/engenharia/tela_lista_processos.dart';
import 'screens/engenharia/tela_lista_produtos.dart';
import 'screens/engenharia/tela_lista_fichas.dart';

import 'screens/comercial/tela_comercial_menu.dart';
import 'screens/comercial/tela_aprovacao_cliente.dart';
import 'screens/pcp/tela_maestro_pcp.dart';

import 'gestao_sistema/telas/tela_dashboard_admin.dart';
import 'screens/autenticacao/tela_login.dart';
import 'screens/rh/tela_gestao_usuarios.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  runApp(const NoEixoTextilApp());
}

class NoEixoTextilApp extends StatelessWidget {
  const NoEixoTextilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoEixo ERP', // Tornando o nome global
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
      ),
      debugShowCheckedModeBanner: false,
      onGenerateInitialRoutes: (String initialRouteName) {
        if (initialRouteName.startsWith('/aprovar')) {
          final uri = Uri.parse(initialRouteName);
          final idPedido = uri.queryParameters['id'];
          final tokenValida = uri.queryParameters['token'];

          if (idPedido != null && tokenValida != null) {
            return [
              MaterialPageRoute(
                builder: (context) => TelaAprovacaoCliente(
                  pedidoId: idPedido,
                  token: tokenValida,
                ),
              ),
            ];
          }
        }
        return [
          MaterialPageRoute(builder: (context) => const RoteadorAutenticacao()),
        ];
      },
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/aprovar')) {
          final uri = Uri.parse(settings.name!);
          final idPedido = uri.queryParameters['id'];
          final tokenValida = uri.queryParameters['token'];

          if (idPedido != null && tokenValida != null) {
            return MaterialPageRoute(
              builder: (context) =>
                  TelaAprovacaoCliente(pedidoId: idPedido, token: tokenValida),
            );
          }
        }
        return null;
      },
    );
  }
}

class RoteadorAutenticacao extends StatelessWidget {
  const RoteadorAutenticacao({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.blueGrey,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return TelaPrincipal(emailUser: snapshot.data!.email);
        }
        return const TelaLogin();
      },
    );
  }
}

class ModuloItem {
  final String nomeChave;
  final IconData icone;
  final String tituloExibicao;
  final Widget telaWidget;

  ModuloItem({
    required this.nomeChave,
    required this.icone,
    required this.tituloExibicao,
    required this.telaWidget,
  });
}

class TelaPrincipal extends StatefulWidget {
  final String? emailUser;
  const TelaPrincipal({super.key, this.emailUser});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _indiceAtual = 0;

  @override
  Widget build(BuildContext context) {
    final String emailSessao = widget.emailUser ?? 'admin@noeixo.com.br';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(emailSessao)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return _construirInterfaceERP(
            context,
            ['Dashboard'],
            false,
            'DEMO_ID',
            'operador',
            ['Dashboard'],
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final String perfil = userData['perfil'] ?? 'operador';
        final String empresaId = userData['empresa_id'] ?? '';

        final List<dynamic> modulosUsuarioRaw =
            userData['modulos_permitidos'] ?? ['Dashboard'];
        final List<String> modulosUsuario = modulosUsuarioRaw
            .map((e) => e.toString())
            .toList();

        if (perfil == 'admin_noeixo') {
          // ADICIONADO O MÓDULO DE LOGÍSTICA AQUI
          final todasAsAbas = [
            'Dashboard',
            'Suprimentos',
            'Comercial',
            'Engenharia',
            'PCP',
            'Produção',
            'Logística', // <-- NOVO
            'Financeiro',
            'RH',
          ];
          return _construirInterfaceERP(
            context,
            todasAsAbas,
            true,
            'HOLDING_DEV',
            perfil,
            todasAsAbas,
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas')
              .doc(empresaId)
              .snapshots(),
          builder: (context, empSnapshot) {
            if (!empSnapshot.hasData || !empSnapshot.data!.exists) {
              return _construirInterfaceERP(
                context,
                ['Dashboard'],
                false,
                empresaId,
                perfil,
                ['Dashboard'],
              );
            }

            final empData = empSnapshot.data!.data() as Map<String, dynamic>;
            final List<dynamic> modulosAtivosRaw =
                empData['modulos_ativos'] ?? ['Dashboard'];
            final List<String> modulosAtivosCampany = modulosAtivosRaw
                .map((e) => e.toString())
                .toList();

            List<String> modulosFinaisAcesso;

            if (perfil == 'master') {
              modulosFinaisAcesso = modulosAtivosCampany;
            } else {
              modulosFinaisAcesso = modulosUsuario
                  .where((modulo) => modulosAtivosCampany.contains(modulo))
                  .toList();
            }

            if (!modulosFinaisAcesso.contains('Dashboard')) {
              modulosFinaisAcesso.insert(0, 'Dashboard');
            }

            return _construirInterfaceERP(
              context,
              modulosFinaisAcesso,
              false,
              empresaId,
              perfil,
              modulosAtivosCampany,
            );
          },
        );
      },
    );
  }

  Widget _construirInterfaceERP(
    BuildContext context,
    List<String> modulosParaExibir,
    bool exibeCentralAdmin,
    String empresaId,
    String perfil,
    List<String> modulosTotaisContratados,
  ) {
    final List<ModuloItem> catalogoModulosOpcionais = [
      ModuloItem(
        nomeChave: 'Dashboard',
        icone: Icons.analytics,
        tituloExibicao: 'Dashboard Operacional',
        telaWidget: const Center(
          child: Text(
            '📊 Dashboard Operacional',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
      ModuloItem(
        nomeChave: 'Suprimentos',
        icone: Icons.shopping_cart,
        tituloExibicao: 'Suprimentos & Matéria-Prima',
        telaWidget: const TelaSuprimentosMenu(),
      ),
      ModuloItem(
        nomeChave: 'Comercial',
        icone: Icons.sell,
        tituloExibicao: 'Vendas & CRM',
        telaWidget: TelaComercialMenu(empresaId: empresaId),
      ),
      ModuloItem(
        nomeChave: 'Engenharia',
        icone: Icons.architecture,
        tituloExibicao: 'Engenharia de Produto',
        telaWidget: TelaEngenhariaMenu(empresaId: empresaId),
      ),
      ModuloItem(
        nomeChave: 'PCP',
        icone: Icons.settings_input_component,
        tituloExibicao: 'Maestro PCP',
        telaWidget: TelaMaestroPCP(empresaId: empresaId),
      ),
      ModuloItem(
        nomeChave: 'Produção',
        icone: Icons.precision_manufacturing,
        tituloExibicao: 'Chão de Fábrica',
        telaWidget: const Center(
          child: Text(
            '⚙️ Apontamento de Produção',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
      // =========================================================================
      // NOVO MÓDULO INJETADO NA ESTRUTURA
      // =========================================================================
      ModuloItem(
        nomeChave: 'Logística',
        icone: Icons.local_shipping,
        tituloExibicao: 'Logística & Expedição',
        telaWidget: const TelaLogisticaMenu(),
      ),
      ModuloItem(
        nomeChave: 'Financeiro',
        icone: Icons.payments,
        tituloExibicao: 'Gestão Financeira',
        telaWidget: TelaFinanceiroMenu(empresaId: empresaId),
      ),
      ModuloItem(
        nomeChave: 'RH',
        icone: Icons.badge_outlined,
        tituloExibicao: 'Recursos Humanos',
        telaWidget: const Center(
          child: Text('👥 Módulo RH', style: TextStyle(fontSize: 20)),
        ),
      ),
    ];

    final List<ModuloItem> menusFiltrados = catalogoModulosOpcionais
        .where((m) => modulosParaExibir.contains(m.nomeChave))
        .toList();

    if (menusFiltrados.isEmpty) {
      menusFiltrados.add(catalogoModulosOpcionais.first);
    }

    final bool possuiAutorizacaoDePainel =
        (perfil == 'master' ||
        perfil == 'admin_noeixo' ||
        modulosParaExibir.contains('Minha Equipe'));

    if (possuiAutorizacaoDePainel) {
      menusFiltrados.add(
        ModuloItem(
          nomeChave: 'Minha Equipe',
          icone: Icons.groups,
          tituloExibicao: 'Controle de Acessos & Equipe',
          telaWidget: TelaGestaoUsuarios(
            empresaId: empresaId,
            modulosEmpresa: modulosTotaisContratados,
          ),
        ),
      );
    }

    if (_indiceAtual >= menusFiltrados.length) _indiceAtual = 0;
    final moduloSelecionado = menusFiltrados[_indiceAtual];

    return Scaffold(
      appBar: AppBar(title: Text(moduloSelecionado.tituloExibicao)),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey),
              child: Center(
                child: Text(
                  'NoEixo ERP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: menusFiltrados.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var mod = entry.value;
                  return ListTile(
                    leading: Icon(
                      mod.icone,
                      color: _indiceAtual == idx
                          ? Colors.blueGrey
                          : Colors.grey,
                    ),
                    title: Text(
                      mod.nomeChave,
                      style: TextStyle(
                        color: _indiceAtual == idx
                            ? Colors.blueGrey
                            : Colors.black87,
                        fontWeight: _indiceAtual == idx
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: _indiceAtual == idx,
                    onTap: () {
                      setState(() => _indiceAtual = idx);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
            if (exibeCentralAdmin) ...[
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Central SaaS (NoEixo)',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TelaDashboardAdmin(),
                    ),
                  );
                },
              ),
            ],
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'v 1.9.0 - Multi-Setorial',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: moduloSelecionado.telaWidget,
    );
  }
}

// --- MENUS DE SUB-ABAS RESPONSIVOS ---
Widget _botaoMenuResponsivo(
  BuildContext context,
  String titulo,
  IconData icone,
  Color cor,
  Widget destino,
) {
  double largura = MediaQuery.of(context).size.width;
  double tamanhoIcone = largura > 600 ? 30 : 40;
  double tamanhoFonte = largura > 600 ? 12 : 14;
  return InkWell(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => destino),
    ),
    child: Card(
      elevation: 4,
      color: cor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: tamanhoIcone, color: Colors.white),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: tamanhoFonte,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// =========================================================================
// TELA DO SUB-MENU: LOGÍSTICA & EXPEDIÇÃO (NOVA)
// =========================================================================
class TelaLogisticaMenu extends StatelessWidget {
  const TelaLogisticaMenu({super.key});

  @override
  Widget build(BuildContext context) {
    double largura = MediaQuery.of(context).size.width;
    int colunas = largura > 800 ? 4 : 2;
    return GridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: colunas,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _botaoMenuResponsivo(
          context,
          'Estoque Produto Acabado',
          Icons.inventory_2,
          Colors.blueGrey,
          Scaffold(
            appBar: AppBar(title: const Text('Estoque Produto Acabado')),
          ), // Temporário até criarmos a tela
        ),
        _botaoMenuResponsivo(
          context,
          'Separação (Picking)',
          Icons.checklist_rtl,
          Colors.indigo,
          Scaffold(appBar: AppBar(title: const Text('Separação de Pedidos'))),
        ),
        _botaoMenuResponsivo(
          context,
          'Embalagem (Packing)',
          Icons.all_inbox,
          Colors.teal,
          Scaffold(
            appBar: AppBar(title: const Text('Embalagem & Conferência')),
          ),
        ),
        _botaoMenuResponsivo(
          context,
          'Despacho & Romaneios',
          Icons.local_shipping,
          Colors.brown,
          Scaffold(appBar: AppBar(title: const Text('Despacho de Carga'))),
        ),
      ],
    );
  }
}

class TelaSuprimentosMenu extends StatelessWidget {
  const TelaSuprimentosMenu({super.key});
  @override
  Widget build(BuildContext context) {
    double largura = MediaQuery.of(context).size.width;
    int colunas = largura > 800 ? 4 : 2;
    return GridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: colunas,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _botaoMenuResponsivo(
          context,
          'Fornecedores',
          Icons.business,
          Colors.blueGrey,
          const TelaFornecedores(),
        ),
        _botaoMenuResponsivo(
          context,
          'Categorias & Insumos',
          Icons.account_tree,
          Colors.indigo,
          const TelaAbasSuprimentos(),
        ),
        _botaoMenuResponsivo(
          context,
          'Entrada / Conferência',
          Icons.assignment_returned,
          Colors.teal,
          const TelaEntradaConferencia(),
        ),
        _botaoMenuResponsivo(
          context,
          'Estoque Matéria-Prima',
          Icons.inventory,
          Colors.brown,
          const TelaEstoqueMateriaPrima(),
        ),
      ],
    );
  }
}

class TelaEngenhariaMenu extends StatelessWidget {
  final String empresaId;
  const TelaEngenhariaMenu({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    double largura = MediaQuery.of(context).size.width;
    int colunas = largura > 800 ? 4 : 2;
    return GridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: colunas,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _botaoMenuResponsivo(
          context,
          'Cadastros Base',
          Icons.inventory_2,
          Colors.blueGrey,
          const TelaCadastrosBase(),
        ),
        _botaoMenuResponsivo(
          context,
          'Produtos',
          Icons.category,
          Colors.indigo,
          TelaListaProdutos(empresaId: empresaId),
        ),
        _botaoMenuResponsivo(
          context,
          'Processos',
          Icons.account_tree,
          Colors.teal,
          const TelaListaProcessos(),
        ),
        _botaoMenuResponsivo(
          context,
          'Fichas Técnicas',
          Icons.description,
          Colors.brown,
          TelaListaFichas(empresaId: empresaId),
        ),
        _botaoMenuResponsivo(
          context,
          'Dicionário de Qualidade',
          Icons.verified_outlined,
          Colors.deepPurple,
          const TelaParametrosQualidade(),
        ),
      ],
    );
  }
}
