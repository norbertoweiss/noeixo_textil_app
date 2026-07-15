import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../forms/form_ficha_cliente.dart';

// O Super Motor agora aceita injetar qualquer modelo de Cartão!
typedef CartaoBuilder =
    Widget Function(
      BuildContext context,
      QueryDocumentSnapshot doc,
      Map<String, dynamic> data,
    );

class MotorListaClientes extends StatelessWidget {
  final String empresaId;
  final String termoBusca;
  final String filtroAtivo;
  final String filtroStatus;
  final String filtroRepresentante;

  // Filtros Geográficos Opcionais (se a tela não passar, ele ignora)
  final String filtroUf;
  final List<String> filtrosCidades;

  // Permite que a tela injete o layout do cartão. Se for nulo, usa o padrão administrativo.
  final CartaoBuilder? cartaoCustomizado;

  const MotorListaClientes({
    super.key,
    required this.empresaId,
    required this.termoBusca,
    required this.filtroAtivo,
    required this.filtroStatus,
    required this.filtroRepresentante,
    this.filtroUf = 'Todas',
    this.filtrosCidades = const [],
    this.cartaoCustomizado,
  });

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('clientes')
        .where('empresa_id', isEqualTo: empresaId);

    if (filtroRepresentante != 'Todos') {
      query = query.where('representante_id', isEqualTo: filtroRepresentante);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: Text(
              'Erro: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(
            child: Text(
              'Nenhum cliente na base de dados.',
              style: TextStyle(color: Colors.grey),
            ),
          );

        var docsFiltrados = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;

          String razao = (data['razao_social'] ?? '').toString().toLowerCase();
          String fantasia = (data['nome_fantasia'] ?? '')
              .toString()
              .toLowerCase();
          String cnpj = (data['cnpj'] ?? '').toString();
          String ie = (data['ie'] ?? '').toString().toLowerCase();

          // Leitura Elástica Geográfica (A "fonte da verdade")
          String ufCliente =
              (data['estado'] ?? data['uf_fiscal'] ?? data['uf'] ?? '')
                  .toString()
                  .toUpperCase()
                  .trim();
          String cidadeCliente =
              (data['cidade'] ??
                      data['cidade_fiscal'] ??
                      data['municipio'] ??
                      '')
                  .toString()
                  .toUpperCase()
                  .trim();

          String statusCreditoDB = data['status_credito'] ?? 'Em Análise';
          String statusCreditoUI =
              (statusCreditoDB == 'Pendente Enriquecimento')
              ? 'Pendente Cadastro'
              : statusCreditoDB;

          bool isRascunho = data['is_rascunho'] ?? false;
          bool isAtivo = data['ativo'] ?? true;

          // Filtro Ativo/Inativo
          if (filtroAtivo == 'Ativos' && !isAtivo) return false;
          if (filtroAtivo == 'Inativos' && isAtivo) return false;

          // Filtro Status
          if (filtroStatus == 'Rascunho' && !isRascunho) return false;
          if (filtroStatus != 'Todos' && filtroStatus != 'Rascunho') {
            if (isRascunho || statusCreditoUI != filtroStatus) return false;
          }

          // Filtros Geográficos
          if (filtroUf != 'Todas' && ufCliente != filtroUf) return false;
          if (filtrosCidades.isNotEmpty &&
              !filtrosCidades.contains(cidadeCliente))
            return false;

          // Filtro de Busca (Texto)
          if (termoBusca.isNotEmpty) {
            String busca = termoBusca.toLowerCase();
            if (!razao.contains(busca) &&
                !fantasia.contains(busca) &&
                !cnpj.contains(busca) &&
                !ie.contains(busca)) {
              return false;
            }
          }

          return true;
        }).toList();

        // ORDENAÇÃO TRIPLA: 1º UF, 2º Cidade, 3º Razão Social
        docsFiltrados.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;

          String ufA =
              (dataA['estado'] ?? dataA['uf_fiscal'] ?? dataA['uf'] ?? '')
                  .toString()
                  .toUpperCase()
                  .trim();
          String ufB =
              (dataB['estado'] ?? dataB['uf_fiscal'] ?? dataB['uf'] ?? '')
                  .toString()
                  .toUpperCase()
                  .trim();
          int comparaUf = ufA.compareTo(ufB);
          if (comparaUf != 0) return comparaUf;

          String cidA =
              (dataA['cidade'] ??
                      dataA['cidade_fiscal'] ??
                      dataA['municipio'] ??
                      '')
                  .toString()
                  .toUpperCase()
                  .trim();
          String cidB =
              (dataB['cidade'] ??
                      dataB['cidade_fiscal'] ??
                      dataB['municipio'] ??
                      '')
                  .toString()
                  .toUpperCase()
                  .trim();
          int comparaCid = cidA.compareTo(cidB);
          if (comparaCid != 0) return comparaCid;

          String nomeA = (dataA['razao_social'] ?? '').toString().toLowerCase();
          String nomeB = (dataB['razao_social'] ?? '').toString().toLowerCase();
          return nomeA.compareTo(nomeB);
        });

        if (docsFiltrados.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum cliente encontrado com estes filtros.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docsFiltrados.length,
          itemBuilder: (context, index) {
            var doc = docsFiltrados[index];
            var data = doc.data() as Map<String, dynamic>;

            // Se a tela passou um layout customizado (como o CardClienteRota), usa ele!
            if (cartaoCustomizado != null) {
              return cartaoCustomizado!(context, doc, data);
            }

            // ================================================================
            // CASO CONTRÁRIO, RENDERIZA O CARTÃO ADMINISTRATIVO PADRÃO
            // ================================================================
            String textoIE =
                data['ie'] != null && data['ie'].toString().trim().isNotEmpty
                ? '  |  IE: ${data['ie']}'
                : '';
            String cidadeAdmin =
                (data['cidade'] ?? data['cidade_fiscal'] ?? '-')
                    .toString()
                    .toUpperCase();
            String estadoAdmin = (data['estado'] ?? data['uf_fiscal'] ?? '-')
                .toString()
                .toUpperCase();

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: const Icon(Icons.business, color: Colors.indigo),
                ),
                title: Text(
                  data['razao_social']?.isNotEmpty == true
                      ? data['razao_social']
                      : 'Razão Social não informada',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CNPJ: ${data['cnpj'] ?? 'S/N'}$textoIE',
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                    Text('Cidade: $cidadeAdmin / $estadoAdmin'),
                  ],
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FormFichaCliente(
                          empresaId: empresaId,
                          clienteId: doc.id,
                          dadosIniciais: data,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade50,
                    foregroundColor: Colors.indigo.shade800,
                    elevation: 0,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
