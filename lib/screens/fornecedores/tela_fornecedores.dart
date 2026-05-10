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
  String _termoBusca = '';
  String? _filtroClasse;
  String? _filtroSubclasse;
  String _filtroStatus = 'Ativos';
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

  void _limparTela() {
    setState(() {
      _termoBusca = '';
      _filtroClasse = null;
      _filtroSubclasse = null;
      _filtroStatus = 'Ativos';
      _mostrarTodos = false;
    });
  }

  // --- MAGIA 1: Corta os parênteses para o nome caber no botão quadrado ---
  String _formatarNomeCurto(String nomeCompleto) {
    int indexParenteses = nomeCompleto.indexOf('(');
    if (indexParenteses != -1) {
      return nomeCompleto.substring(0, indexParenteses).trim();
    }
    return nomeCompleto;
  }

  // --- MAGIA 2: Ícones automáticos baseados no nome da categoria ---
  IconData _getIconeParaCategoria(String nome) {
    final n = nome.toLowerCase();
    if (n.contains('ativo') || n.contains('investimento'))
      return Icons.account_balance;
    if (n.contains('consumo')) return Icons.precision_manufacturing;
    if (n.contains('administrativa')) return Icons.folder_open;
    if (n.contains('fixas') || n.contains('ocupação'))
      return Icons.receipt_long;
    if (n.contains('insumos') || n.contains('produção'))
      return Icons.inventory_2;
    if (n.contains('infraestrutura') || n.contains('manutenção'))
      return Icons.handyman;
    if (n.contains('rh') || n.contains('segurança'))
      return Icons.health_and_safety;
    if (n.contains('serviços') || n.contains('terceirizados'))
      return Icons.handshake;
    return Icons.category; // Ícone padrão genérico
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: Colors.grey.shade50,
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
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (valor) =>
                  setState(() => _termoBusca = valor.toLowerCase()),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- LINHA 1: BOTÕES QUADRADOS (GRID RESPONSIVO) ---
          if (_categorias.isNotEmpty)
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center, // Centraliza os quadradinhos
                children: _categorias.map((doc) {
                  String nomeCompleto = doc['nome'].toString();
                  bool selecionado = _filtroClasse == nomeCompleto;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _filtroClasse = selecionado
                            ? null
                            : nomeCompleto; // Clicar de novo desmarca
                        _filtroSubclasse = null;
                        _mostrarTodos = false;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width:
                          82, // Largura exata para caberem 4 botões num telemóvel padrão (fechando 2 linhas perfeitas)
                      height: 82,
                      decoration: BoxDecoration(
                        color: selecionado ? Colors.blueGrey : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selecionado
                              ? Colors.blueGrey
                              : Colors.grey.shade300,
                        ),
                        boxShadow: selecionado
                            ? [
                                BoxShadow(
                                  color: Colors.blueGrey.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getIconeParaCategoria(nomeCompleto),
                            color: selecionado
                                ? Colors.white
                                : Colors.blueGrey.shade400,
                            size: 26,
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.0,
                            ),
                            child: Text(
                              _formatarNomeCurto(nomeCompleto),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                height:
                                    1.1, // Reduz o espaço entre as linhas do texto
                                color: selecionado
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: selecionado
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // --- LINHA 2: FILTROS DE SUBCLASSES (MANTIDOS COMO "PÍLULAS" PARA NÃO POLUIR) ---
          if (_filtroClasse != null && subclassesAtuais.isNotEmpty)
            Container(
              color: Colors.blueGrey.shade50,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 6.0,
                runSpacing: 4.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(
                    Icons.subdirectory_arrow_right,
                    color: Colors.blueGrey,
                    size: 18,
                  ),
                  ...subclassesAtuais.map((subNome) {
                    bool selecionado = _filtroSubclasse == subNome;
                    return ChoiceChip(
                      label: Text(subNome),
                      selected: selecionado,
                      onSelected: (sel) {
                        setState(() => _filtroSubclasse = sel ? subNome : null);
                      },
                      selectedColor: Colors.teal,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selecionado ? Colors.white : Colors.black87,
                        fontSize: 12,
                        fontWeight: selecionado
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 0,
                      ),
                    );
                  }),
                ],
              ),
            ),

          // --- LINHA 3: STATUS (ATIVOS/INATIVOS) E LIMPAR ---
          if (!telaLimpa)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _chipStatus('Ativos', Colors.green),
                      const SizedBox(width: 6),
                      _chipStatus('Inativos', Colors.red),
                      const SizedBox(width: 6),
                      _chipStatus('Todos', Colors.blueGrey),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _limparTela,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Limpar', style: TextStyle(fontSize: 12)),
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
              'Consulta Rápida',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toque numa categoria acima\nou faça uma busca.',
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

  Widget _chipStatus(String rotulo, Color corFundo) {
    bool selecionado = _filtroStatus == rotulo;
    return ChoiceChip(
      label: Text(rotulo),
      selected: selecionado,
      onSelected: (sel) {
        if (sel) setState(() => _filtroStatus = rotulo);
      },
      selectedColor: corFundo.withOpacity(0.2),
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        color: selecionado
            ? corFundo.withRed(corFundo.red ~/ 1.5)
            : Colors.black54,
        fontSize: 11,
        fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: selecionado ? corFundo : Colors.grey.shade300),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
    );
  }

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

          if (_filtroStatus == 'Ativos' && !ativo) return false;
          if (_filtroStatus == 'Inativos' && ativo) return false;

          bool matchTexto =
              _termoBusca.isEmpty ||
              nome.contains(_termoBusca) ||
              fantasia.contains(_termoBusca) ||
              documento.contains(_termoBusca) ||
              classeFornecedor.toLowerCase().contains(_termoBusca) ||
              subclasseFornecedor.toLowerCase().contains(_termoBusca);

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
              'Nenhum resultado encontrado.',
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
              color: ativo ? Colors.white : Colors.grey.shade100,
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
