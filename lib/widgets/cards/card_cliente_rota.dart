import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../modals/modal_registro_crm.dart';
import '../../screens/comercial/operacional/tela_completar_cadastro.dart';
import '../../screens/comercial/operacional/tela_edicao_cliente.dart';
import '../../screens/comercial/form_pedido_venda.dart';

class CardClienteRota extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final String empresaId;
  final String representanteId;

  const CardClienteRota({
    super.key,
    required this.doc,
    required this.data,
    required this.empresaId,
    required this.representanteId,
  });

  @override
  Widget build(BuildContext context) {
    String statusCreditoDB = data['status_credito'] ?? 'Em Análise';
    String statusCreditoUI = (statusCreditoDB == 'Pendente Enriquecimento')
        ? 'Pendente Cadastro'
        : statusCreditoDB;

    bool isRascunho = data['is_rascunho'] ?? false;
    bool isAtivo = data['ativo'] ?? true;
    bool isDoBolsao = data['representante_id'] == 'Lista Clientes Importada';

    if (isRascunho) {
      return Card(
        color: Colors.orange.shade50,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.orange,
            child: Icon(Icons.edit_document, color: Colors.white),
          ),
          title: Text(
            data['razao_social'] ?? 'Sem Razão Social',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            '⚠️ Rascunho Incompleto.\nFalta endereço logístico e GPS.',
            style: TextStyle(color: Colors.deepOrange, fontSize: 12),
          ),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TelaCompletarCadastro(
                  clienteId: doc.id,
                  dadosIniciais: data,
                ),
              ),
            ),
            child: const Text('Completar'),
          ),
        ),
      );
    }

    // ========================================================================
    // LEITURA ELÁSTICA DOS DADOS GEOGRÁFICOS E CADASTRAIS
    // ========================================================================
    String cidade =
        (data['cidade'] ??
                data['cidade_fiscal'] ??
                data['municipio'] ??
                'Sem Cidade')
            .toString()
            .toUpperCase();
    String bairro = (data['bairro'] ?? data['bairro_fiscal'] ?? 'Sem Bairro')
        .toString()
        .toUpperCase();

    return Card(
      color: isAtivo ? Colors.white : Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        // ====================================================================
        // TOQUE NO CORPO DO CARD ABRE A EDIÇÃO
        // ====================================================================
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TelaEdicaoClienteCompleta(
                clienteId: doc.id,
                dadosIniciais: data,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: !isAtivo
                  ? Colors.grey.shade400
                  : statusCreditoUI == 'Aprovado'
                  ? Colors.green[100]
                  : (statusCreditoUI == 'Bloqueado'
                        ? Colors.red[100]
                        : Colors.blue[100]),
              child: Icon(
                !isAtivo
                    ? Icons.business_outlined
                    : statusCreditoUI == 'Aprovado'
                    ? Icons.store
                    : (statusCreditoUI == 'Bloqueado'
                          ? Icons.block
                          : Icons.hourglass_empty),
                color: !isAtivo
                    ? Colors.white
                    : statusCreditoUI == 'Aprovado'
                    ? Colors.green
                    : (statusCreditoUI == 'Bloqueado'
                          ? Colors.red
                          : Colors.blue),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    data['razao_social'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isAtivo ? Colors.black : Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isAtivo)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'INATIVO',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '$cidade - $bairro\nCrédito: $statusCreditoUI',
                  style: const TextStyle(fontSize: 12),
                ),
                if (isDoBolsao)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.deepPurple.shade200),
                    ),
                    child: Text(
                      'BASE COMPARTILHADA (SEM DONO)',
                      style: TextStyle(
                        color: Colors.deepPurple.shade800,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            // ====================================================================
            // AÇÕES DIRETAS (LADO DIREITO)
            // ====================================================================
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ÍCONE DE VISITA (CRM)
                IconButton(
                  icon: const Icon(
                    Icons.handshake,
                    color: Colors.orange,
                    size: 26,
                  ),
                  tooltip: 'Registrar Visita',
                  onPressed: () {
                    mostrarModalCRM(
                      context,
                      clienteId: doc.id,
                      nomeCliente: data['razao_social'] ?? 'Sem Nome',
                      representanteId: representanteId,
                    );
                  },
                ),
                // ÍCONE DE PEDIDO (APENAS ATIVOS)
                if (isAtivo)
                  IconButton(
                    icon: const Icon(
                      Icons.shopping_cart_checkout,
                      color: Colors.indigo,
                      size: 26,
                    ),
                    tooltip: 'Novo Pedido',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FormPedidoVenda(
                            empresaId: empresaId,
                            clienteId: doc.id,
                            clienteNome:
                                data['razao_social'] ?? 'Cliente Sem Nome',
                            // CORREÇÃO CRÍTICA ABAIXO: Pega a região ou a cidade do cliente
                            regiao: data['regiao'] ?? cidade,
                            whatsappCliente: data['whatsapp'] ?? '',
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
