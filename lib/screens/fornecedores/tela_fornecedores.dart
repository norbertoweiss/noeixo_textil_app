import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'form_fornecedor.dart';
import 'tela_categorias_fornecedor.dart';

class TelaFornecedores extends StatefulWidget {
  const TelaFornecedores({super.key});

  @override
  State<TelaFornecedores> createState() => _TelaFornecedoresState();
}

class _TelaFornecedoresState extends State<TelaFornecedores> {
  // Controles de Busca e Filtros
  String _termoBusca = '';
  String? _filtroClasse;
  String? _filtroSubclasse;
  String _filtroStatus = 'Ativos'; // Pode ser 'Ativos', 'Inativos' ou 'Todos'

  // Gatilho para mostrar todos os registros (quebra o ecrã limpo)
  bool _mostrarTodos = false;

  List<DocumentSnapshot> _categorias = [];

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
  }

  Future<void> _carregarCategorias() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('categorias_fornecedor')
        .where('clienteId', isEqualTo: 'teste_textil')
        .where('ativo', isEqualTo: true)
        .get();

    if (mounted) {
      setState(() {
        _categorias = snapshot.docs;
        _categorias.sort(
          (a, b) => a['nome'].toString().compareTo(b['nome'].toString()),
        );
      });
    }
  }

  Future<void> _alterarStatusFornecedor(String id, bool novoStatus) async {
    await FirebaseFirestore.instance.collection('fornecedores').doc(id).update({
      'ativo': novoStatus,
    });
  }

  Future<void> _abrirWhatsAppDiretoLista(
    BuildContext context,
    String telefone,
  ) async {
    String numero = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    if (numero.isEmpty) return;
    if (!numero.startsWith('55')) numero = '55$numero';

    final Uri url = Uri.parse('https://wa.me/$numero');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    }
  }

  // Função que limpa totalmente a tela e reseta os filtros
  void _limparTela() {
    setState(() {
      _termoBusca = '';
      _filtroClasse = null;
      _filtroSubclasse = null;
      _filtroStatus = 'Ativos';
      _mostrarTodos = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Verifica se a tela deve ficar no modo "Limpo" (Nenhum filtro ou busca ativa)
    bool telaLimpa =
        _termoBusca.isEmpty && _filtroClasse == null && !_mostrarTodos;

    List<String> subclassesAtuais = [];
    if (_filtroClasse != null) {
      var catDoc = _categorias.firstWhere(
        (doc) => doc['nome'] == _filtroClasse,
      );
      var subList = catDoc['subgrupos'] ?? [];
      subclassesAtuais = subList.map<String>((e) {
        if (e is Map) return e['nome'].toString();
        return e.toString();
      }).toList();
      subclassesAtuais.sort((a, b) => a.compareTo(b));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueGrey,
        elevation: 1,
        title: const Text('Fornecedores e Parceiros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            tooltip: 'Configurar Classes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TelaCategoriasFornecedor(),
                ),
              ).then((_) => _carregarCategorias());
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar nome ou CNPJ...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _termoBusca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _limparTela,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (valor) =>
                  setState(() => _termoBusca = valor.toLowerCase()),
              // Se tiver um controlador, seria bom limpar o campo visualmente no _limparTela,
              // mas como estamos só a alterar o estado, o usuário pode apagar o texto à mão.
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- LINHA 1: FILTROS DE CLASSES ---
          if (_categorias.isNotEmpty)
            Container(
              color: Colors.white,
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: _categorias.map((doc) {
                    String nome = doc['nome'].toString();
                    bool selecionado = _filtroClasse == nome;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(nome),
                        selected: selecionado,
                        onSelected: (sel) {
                          setState(() {
                            _filtroClasse = sel ? nome : null;
                            _filtroSubclasse = null;
                            _mostrarTodos =
                                false; // Se clicou na classe, já não é "Mostrar Todos", é busca filtrada
                          });
                        },
                        selectedColor: Colors.blueGrey,
                        labelStyle: TextStyle(
                          color: selecionado ? Colors.white : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // --- LINHA 2: FILTROS DE SUBCLASSES ---
          if (_filtroClasse != null && subclassesAtuais.isNotEmpty)
            Container(
              color: Colors.blueGrey.shade50,
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right,
                      color: Colors.blueGrey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    ...subclassesAtuais.map((subNome) {
                      bool selecionado = _filtroSubclasse == subNome;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(subNome),
                          selected: selecionado,
                          onSelected: (sel) {
                            setState(
                              () => _filtroSubclasse = sel ? subNome : null,
                            );
                          },
                          selectedColor: Colors.teal,
                          labelStyle: TextStyle(
                            color: selecionado ? Colors.white : Colors.black87,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // --- LINHA 3: STATUS (ATIVOS/INATIVOS) E LIMPAR ---
          // Só mostra esta barra se não estiver no ecrã limpo
          if (!telaLimpa)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _chipStatus('Ativos', Colors.green),
                      const SizedBox(width: 8),
                      _chipStatus('Inativos', Colors.red),
                      const SizedBox(width: 8),
                      _chipStatus('Todos', Colors.blueGrey),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _limparTela,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Limpar'),
                  ),
                ],
              ),
            ),

          // --- CORPO PRINCIPAL (ECRÃ LIMPO OU LISTA) ---
          Expanded(
            child: telaLimpa
                ? _construirEcraLimpo()
                : _construirListaFornecedores(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueGrey,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FormFornecedor()),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Novo', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // COMPONENTE: Ecrã Limpo Inicial
  Widget _construirEcraLimpo() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.manage_search,
              size: 80,
              color: Colors.blueGrey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Consulta de Fornecedores',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Digite um nome ou escolha uma classe acima\npara iniciar a sua busca.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => setState(() => _mostrarTodos = true),
              icon: const Icon(Icons.list_alt),
              label: const Text('Ver Todos os Cadastros'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // COMPONENTE: Chip de Status
  Widget _chipStatus(String rotulo, Color corFundo) {
    bool selecionado = _filtroStatus == rotulo;
    return ChoiceChip(
      label: Text(rotulo),
      selected: selecionado,
      onSelected: (sel) {
        if (sel) setState(() => _filtroStatus = rotulo);
      },
      selectedColor: corFundo.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selecionado
            ? corFundo.withRed(corFundo.red ~/ 1.5)
            : Colors.black54, // Escurece um pouco a cor do texto
        fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: selecionado ? corFundo : Colors.grey.shade300),
    );
  }

  // COMPONENTE: A Lista Filtrada do Firebase
  Widget _construirListaFornecedores() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fornecedores')
          .where('clienteId', isEqualTo: 'teste_textil')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(child: Text('Nenhum fornecedor cadastrado.'));

        var documentos = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nome = (data['nome'] ?? '').toString().toLowerCase();
          final fantasia = (data['nomeFantasia'] ?? '')
              .toString()
              .toLowerCase();
          final documento = (data['documento'] ?? '').toString().toLowerCase();
          final classeFornecedor = (data['grupoNome'] ?? '').toString();
          final subclasseFornecedor = (data['subcategoria'] ?? '').toString();
          final ativo = data['ativo'] ?? true;

          // REGRA 1: Filtro de Status (Ativo/Inativo/Todos)
          if (_filtroStatus == 'Ativos' && !ativo) return false;
          if (_filtroStatus == 'Inativos' && ativo) return false;

          // REGRA 2: Busca por Texto
          bool matchTexto =
              _termoBusca.isEmpty ||
              nome.contains(_termoBusca) ||
              fantasia.contains(_termoBusca) ||
              documento.contains(_termoBusca) ||
              classeFornecedor.toLowerCase().contains(_termoBusca) ||
              subclasseFornecedor.toLowerCase().contains(_termoBusca);

          // REGRA 3: Filtro de Classes e Subclasses
          bool matchClasse =
              _filtroClasse == null || classeFornecedor == _filtroClasse;
          bool matchSubclasse =
              _filtroSubclasse == null ||
              subclasseFornecedor == _filtroSubclasse;

          return matchTexto && matchClasse && matchSubclasse;
        }).toList();

        if (documentos.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum resultado encontrado para estes filtros.',
              style: TextStyle(fontSize: 16, color: Colors.blueGrey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: documentos.length,
          itemBuilder: (context, index) {
            final data = documentos[index].data() as Map<String, dynamic>;
            final id = documentos[index].id;
            final ativo = data['ativo'] ?? true;

            String empresaPhone = data['contato'] ?? '';
            String vendedorPhone = data['whatsappVendedor'] ?? '';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 10),
              color: ativo
                  ? Colors.white
                  : Colors.grey.shade100, // Escurece o card se for Inativo
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: ativo
                      ? Colors.blueGrey[100]
                      : Colors.grey[300],
                  child: Icon(
                    Icons.business,
                    color: ativo ? Colors.blueGrey : Colors.grey,
                  ),
                ),
                title: Text(
                  data['nome'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: ativo
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                    color: ativo ? Colors.black87 : Colors.grey,
                  ),
                ),

                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text('CNPJ/CPF: ${data['documento']}'),

                    const SizedBox(height: 4),
                    if (empresaPhone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.business,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            empresaPhone,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _abrirWhatsAppDiretoLista(
                              context,
                              empresaPhone,
                            ),
                            child: Icon(
                              Icons.chat,
                              color: ativo ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 4),
                    if (vendedorPhone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            vendedorPhone,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _abrirWhatsAppDiretoLista(
                              context,
                              vendedorPhone,
                            ),
                            child: Icon(
                              Icons.chat,
                              color: ativo ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ativo
                            ? Colors.amberAccent.withOpacity(0.2)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${data['grupoNome']} > ${data['subcategoria']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ativo ? Colors.blueGrey : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                isThreeLine: false,
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.blueGrey,
                        size: 20,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FormFornecedor(
                            fornecedorParaEditar: documentos[index],
                          ),
                        ),
                      ),
                    ),
                    Switch(
                      value: ativo,
                      activeColor: Colors.blueGrey,
                      onChanged: (valor) => _alterarStatusFornecedor(id, valor),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
