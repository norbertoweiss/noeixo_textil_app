import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';

// --- IMPORTAÇÕES DE CADASTROS E SUPRIMENTOS ---
import 'screens/cadastros_base/tela_cadastros_base.dart';
import 'screens/cadastros_base/tela_parametros_qualidade.dart';
import 'screens/fornecedores/tela_fornecedores.dart';
import 'screens/insumos/tela_abas_suprimentos.dart';

// --- IMPORTAÇÕES DO ESTOQUE ---
import 'screens/estoque/tela_entrada_conferencia.dart';
import 'screens/estoque/tela_estoque_materia_prima.dart';

// --- IMPORTAÇÃO DO FINANCEIRO ---
import 'screens/financeiro/tela_financeiro_menu.dart';

// --- IMPORTAÇÕES DA ENGENHARIA ---
import 'screens/engenharia/tela_lista_processos.dart';
import 'screens/engenharia/tela_lista_produtos.dart';
import 'screens/engenharia/tela_lista_fichas.dart';

// --- IMPORTAÇÕES DO COMERCIAL ---
import 'screens/comercial/tela_carteira_clientes.dart';
import 'screens/comercial/tela_gestao_regioes.dart';
import 'screens/comercial/tela_cadastro_vendedor.dart'; // Nova Ficha de Vendedores Conectada

// --- IMPORTAÇÃO DA GESTÃO DO SISTEMA (NOEIXO) ---
import 'gestao_sistema/telas/tela_dashboard_admin.dart';

// --- IMPORTAÇÃO DO MÓDULO DE AUTENTICAÇÃO ---
import 'screens/autenticacao/tela_login.dart';

// --- IMPORTAÇÃO DO MÓDULO DE GESTÃO DE EQUIPE ---
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
      title: 'NoEixo Têxtil',
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
      home: const TelaLogin(),
      debugShowCheckedModeBanner: false,
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
          final todasAsAbas = [
            'Dashboard',
            'Suprimentos',
            'Comercial',
            'Engenharia',
            'PCP',
            'Produção',
            'Financeiro',
            'RH',
          ];
          return _construirInterfaceERP(
            context,
            todasAsAbas,
            true,
            empresaId,
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
        tituloExibicao: 'Suprimentos',
        telaWidget: const TelaSuprimentosMenu(),
      ),

      // SATELLITE UPDATE: Passa o ID da fábrica ativa diretamente para o sub-menu comercial
      ModuloItem(
        nomeChave: 'Comercial',
        icone: Icons.sell,
        tituloExibicao: 'Comercial',
        telaWidget: TelaComercialMenu(empresaId: empresaId),
      ),

      ModuloItem(
        nomeChave: 'Engenharia',
        icone: Icons.architecture,
        tituloExibicao: 'Engenharia & Modelagem',
        telaWidget: const TelaEngenhariaMenu(),
      ),
      ModuloItem(
        nomeChave: 'PCP',
        icone: Icons.settings_input_component,
        tituloExibicao: 'Maestro PCP',
        telaWidget: const Center(
          child: Text('🏭 Maestro PCP', style: TextStyle(fontSize: 20)),
        ),
      ),
      ModuloItem(
        nomeChave: 'Produção',
        icone: Icons.checkroom,
        tituloExibicao: 'Chão de Fábrica',
        telaWidget: const Center(
          child: Text('🧵 Producão', style: TextStyle(fontSize: 20)),
        ),
      ),
      ModuloItem(
        nomeChave: 'Financeiro',
        icone: Icons.payments,
        tituloExibicao: 'Gestão Financeira',
        telaWidget: const TelaFinanceiroMenu(),
      ),
      ModuloItem(
        nomeChave: 'RH',
        icone: Icons.badge_outlined,
        tituloExibicao: 'Recursos Humanos Industrial',
        telaWidget: const Center(
          child: Text(
            '👥 Módulo RH Operacional (Opcional)',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    ];

    final List<ModuloItem> menusFiltrados = catalogoModulosOpcionais
        .where((m) => modulosParaExibir.contains(m.nomeChave))
        .toList();

    if (menusFiltrados.isEmpty)
      menusFiltrados.add(catalogoModulosOpcionais.first);

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
                  'NoEixo Têxtil',
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
                'v 1.8.1',
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
  const TelaEngenhariaMenu({super.key});
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
          const TelaListaProdutos(),
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
          const TelaListaFichas(),
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

class TelaComercialMenu extends StatelessWidget {
  final String empresaId;
  const TelaComercialMenu({super.key, required this.empresaId});

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
          'Carteira & CRM',
          Icons.badge,
          Colors.indigo,
          const TelaCarteiraClientes(),
        ),
        _botaoMenuResponsivo(
          context,
          'Regiões & Territórios',
          Icons.map,
          Colors.deepPurple,
          const TelaGestaoRegioes(),
        ),

        // BOTÃO INTEGRADO: Substitui o botão temporário pela Ficha de Vendedores Real
        _botaoMenuResponsivo(
          context,
          'Cadastro de Vendedores',
          Icons.badge_outlined,
          Colors.teal,
          TelaCadastroVendedor(empresaId: empresaId),
        ),
      ],
    );
  }
}
