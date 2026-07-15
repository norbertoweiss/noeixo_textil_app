import 'package:flutter/material.dart';

class CardClienteGerencial extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onAcaoTransferir;
  final VoidCallback onAcaoCredito;
  final VoidCallback onAcaoEditar;

  const CardClienteGerencial({
    super.key,
    required this.data,
    required this.onAcaoTransferir,
    required this.onAcaoCredito,
    required this.onAcaoEditar,
  });

  @override
  Widget build(BuildContext context) {
    String statusCredito = data['status_credito'] ?? 'Em Análise';
    bool isAtivo = data['ativo'] ?? true;
    String representante = data['representante_id'] ?? 'NÃO ATRIBUÍDO';

    // Define se está na fila de distribuição (Antigo Bolsão)
    bool isNaFila = representante == 'BOLSÃO';

    return Card(
      color: isAtivo ? Colors.white : Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: !isAtivo
              ? Colors.grey.shade400
              : statusCredito == 'Aprovado'
              ? Colors.green[100]
              : (statusCredito == 'Bloqueado'
                    ? Colors.red[100]
                    : Colors.blue[100]),
          child: Icon(
            !isAtivo
                ? Icons.business_outlined
                : statusCredito == 'Aprovado'
                ? Icons.store
                : (statusCredito == 'Bloqueado'
                      ? Icons.block
                      : Icons.hourglass_empty),
            color: !isAtivo
                ? Colors.white
                : statusCredito == 'Aprovado'
                ? Colors.green
                : (statusCredito == 'Bloqueado' ? Colors.red : Colors.blue),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                data['razao_social'] ?? 'Sem Razão Social',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isAtivo ? Colors.black : Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isNaFila)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  border: Border.all(color: Colors.purple.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'FILA DE DISTRIBUIÇÃO',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 9,
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
              '${data['cidade_fiscal']} - ${data['bairro_fiscal']}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Crédito: $statusCredito | Vendedor: ${isNaFila ? 'Pendente' : representante}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade300,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.blueGrey),
          onSelected: (val) {
            if (val == 'transferir') onAcaoTransferir();
            if (val == 'credito') onAcaoCredito();
            if (val == 'editar') onAcaoEditar();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'transferir',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, color: Colors.purple, size: 20),
                  SizedBox(width: 8),
                  Text('Atribuir Vendedor'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'credito',
              child: Row(
                children: [
                  Icon(
                    Icons.monetization_on_outlined,
                    color: Colors.green,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text('Analisar Crédito'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'editar',
              child: Row(
                children: [
                  Icon(Icons.edit_document, color: Colors.blueGrey, size: 20),
                  SizedBox(width: 8),
                  Text('Ficha Completa'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
