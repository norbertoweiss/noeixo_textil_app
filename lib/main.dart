import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';

// --- IMPORTAÇÕES DE CADASTROS E SUPRIMENTOS ---
import 'screens/cadastros_base/tela_cadastros_base.dart';
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

      // CONFIGURAÇÃO DO IDIOMA PORTUGUÊS (BRASIL)
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
      home: const TelaPrincipal(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});
  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _indiceAtual = 0;

  final List<Widget> _telas = [
    const Center(
      child: Text('📊 Dashboard Operacional', style: TextStyle(fontSize: 20)),
    ),
    const TelaSuprimentosMenu(),
    const Center(
      child: Text('🛒 Comercial & Vendas', style: TextStyle(fontSize: 20)),
    ),
    const TelaEngenhariaMenu(),
    const Center(child: Text('🏭 Maestro PCP', style: TextStyle(fontSize: 20))),
    const Center(child: Text('🧵 Produção', style: TextStyle(fontSize: 20))),
    const TelaFinanceiroMenu(),
    const Center(
      child: Text('👥 RH & Pessoas', style: TextStyle(fontSize: 20)),
    ),
  ];

  final List<String> _titulos = [
    'Dashboard',
    'Suprimentos',
    'Comercial',
    'Engenharia',
    'PCP',
    'Produção',
    'Financeiro',
    'RH',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titulos[_indiceAtual])),
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
                children: [
                  _criarItemMenu(0, Icons.analytics, 'Dashboard'),
                  const Divider(),
                  _criarItemMenu(1, Icons.shopping_cart, 'Suprimentos'),
                  _criarItemMenu(2, Icons.sell, 'Comercial'),
                  _criarItemMenu(3, Icons.architecture, 'Engenharia'),
                  _criarItemMenu(4, Icons.settings_input_component, 'PCP'),
                  _criarItemMenu(5, Icons.checkroom, 'Produção'),
                  _criarItemMenu(6, Icons.payments, 'Financeiro'),
                  _criarItemMenu(7, Icons.groups, 'RH'),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'v 1.6.9',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: _telas[_indiceAtual],
    );
  }

  Widget _criarItemMenu(int indice, IconData icone, String rotulo) {
    return ListTile(
      leading: Icon(
        icone,
        color: _indiceAtual == indice ? Colors.blueGrey : Colors.grey,
      ),
      title: Text(
        rotulo,
        style: TextStyle(
          color: _indiceAtual == indice ? Colors.blueGrey : Colors.black87,
          fontWeight: _indiceAtual == indice
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      selected: _indiceAtual == indice,
      onTap: () {
        setState(() => _indiceAtual = indice);
        Navigator.pop(context);
      },
    );
  }
}

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
      ],
    );
  }
}
