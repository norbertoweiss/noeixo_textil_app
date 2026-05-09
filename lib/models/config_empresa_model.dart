import 'package:flutter/material.dart';
import '../../models/grade_model.dart';

class TelaCadastrosBase extends StatefulWidget {
  const TelaCadastrosBase({super.key});

  @override
  State<TelaCadastrosBase> createState() => _TelaCadastrosBaseState();
}

class _TelaCadastrosBaseState extends State<TelaCadastrosBase> {
  // Variável para controlar o filtro selecionado na aba Grades
  String _filtroGrades = 'Todos';

  // Dados fictícios para teste na empresa teste_textil
  List<GradeModel> listaGrades = [
    GradeModel(
      id: '1',
      clienteId: 'teste_textil',
      nome: 'Adulto Padrão',
      tamanhos: ['P', 'M', 'G', 'GG'],
      ativo: true,
    ),
    GradeModel(
      id: '2',
      clienteId: 'teste_textil',
      nome: 'Infantil',
      tamanhos: ['2', '4', '6', '8'],
      ativo: true,
    ),
    GradeModel(
      id: '3',
      clienteId: 'teste_textil',
      nome: 'Moda Praia Antiga',
      tamanhos: ['Único'],
      ativo: false,
    ), // Adicionei um inativo para testar
  ];

  // Função "Get" que devolve a lista filtrada dinamicamente
  List<GradeModel> get gradesFiltradas {
    if (_filtroGrades == 'Ativos') {
      return listaGrades.where((grade) => grade.ativo == true).toList();
    } else if (_filtroGrades == 'Inativos') {
      return listaGrades.where((grade) => grade.ativo == false).toList();
    }
    return listaGrades; // Se for 'Todos', devolve a lista completa
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          toolbarHeight: 0,
          bottom: const TabBar(
            labelColor: Colors.blueGrey,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueGrey,
            tabs: [
              Tab(text: 'Grades'),
              Tab(text: 'Cores'),
              Tab(text: 'Tecidos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- ABA 1: GRADES ---
            Column(
              children: [
                // O Botão Segmentado para o Filtro
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Todos', label: Text('Todos')),
                      ButtonSegment(value: 'Ativos', label: Text('Ativos')),
                      ButtonSegment(value: 'Inativos', label: Text('Inativos')),
                    ],
                    selected: {_filtroGrades},
                    onSelectionChanged: (Set<String> novaSelecao) {
                      setState(() {
                        // Atualiza a variável e reconstrói a tela
                        _filtroGrades = novaSelecao.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: Colors.blueGrey,
                    ),
                  ),
                ),

                // A Lista Filtrada (Expanded para ocupar o resto do espaço)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: gradesFiltradas.length,
                    itemBuilder: (context, index) {
                      final grade = gradesFiltradas[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: grade.ativo
                                ? Colors.blueGrey
                                : Colors.grey[400],
                            child: const Icon(
                              Icons.straighten,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            grade.nome,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: grade.ativo
                                  ? TextDecoration.none
                                  : TextDecoration.lineThrough,
                              color: grade.ativo ? Colors.black87 : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            'Tamanhos: ${grade.tamanhos.join(" - ")}',
                          ),
                          trailing: Switch(
                            value: grade.ativo,
                            activeColor: Colors.blueGrey,
                            onChanged: (valor) {
                              setState(() {
                                grade.ativo = valor;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // --- ABA 2: CORES ---
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.palette, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Nova Cor'),
                  ),
                ],
              ),
            ),

            // --- ABA 3: TECIDOS ---
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.texture, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Novo Tecido'),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.blueGrey,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('A abrir formulário de registo...')),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
