// Arquivo: lib/services/motor_sortimento_service.dart

class MotorSortimentoService {
  /// Calcula a distribuição de peças entre as cores disponíveis.
  ///
  /// Se [estoquePorCor] for fornecido (Pronta Entrega), o motor prioriza
  /// o escoamento das cores com mais saldo, limitando a 40% para garantir variedade.
  /// Se não for fornecido (Programado), faz uma divisão matemática igualitária.
  static Map<String, int> calcularSortimento({
    required int quantidadeTotal,
    required List<String> coresAtivas,
    Map<String, int>? estoquePorCor,
  }) {
    if (quantidadeTotal <= 0 || coresAtivas.isEmpty) return {};

    Map<String, int> distribuicao = {};
    // Inicializa o mapa com zero para todas as cores
    for (var cor in coresAtivas) {
      distribuicao[cor] = 0;
    }

    // ==========================================
    // LÓGICA 1: PRONTA ENTREGA (Escoamento de Estoque)
    // ==========================================
    if (estoquePorCor != null && estoquePorCor.isNotEmpty) {
      // Ordena as cores da que tem MAIS estoque para a que tem MENOS.
      List<String> coresOrdenadas = List.from(coresAtivas);
      coresOrdenadas.sort((a, b) {
        int estA = estoquePorCor[a] ?? 0;
        int estB = estoquePorCor[b] ?? 0;
        return estB.compareTo(estA); // Ordem Decrescente
      });

      int restante = quantidadeTotal;
      // Trava de Variedade: Nenhuma cor deve ultrapassar 40% do lote (arredondado para cima)
      int limitePorCor = (quantidadeTotal * 0.4).ceil();

      // Primeira Passada: Distribui priorizando estoque alto, mas travado nos 40%
      for (var cor in coresOrdenadas) {
        if (restante <= 0) break;
        int estoqueDisponivel = estoquePorCor[cor] ?? 0;

        if (estoqueDisponivel > 0) {
          int aPegar = limitePorCor < estoqueDisponivel
              ? limitePorCor
              : estoqueDisponivel;
          if (aPegar > restante) aPegar = restante;

          distribuicao[cor] = aPegar;
          restante -= aPegar;
        }
      }

      // Segunda Passada: Se a trava de 40% barrou a venda e ainda sobrou pedido,
      // ignora a trava e "rapa" o que sobrou nos estoques disponíveis.
      if (restante > 0) {
        for (var cor in coresOrdenadas) {
          if (restante <= 0) break;
          int estoqueDisponivel = estoquePorCor[cor] ?? 0;
          int jaPego = distribuicao[cor] ?? 0;
          int saldoReal = estoqueDisponivel - jaPego;

          if (saldoReal > 0) {
            int aPegar = saldoReal > restante ? restante : saldoReal;
            distribuicao[cor] = (distribuicao[cor] ?? 0) + aPegar;
            restante -= aPegar;
          }
        }
      }

      // Terceira Passada: Se AINDA sobrar (o cliente pediu 100 peças e a fábrica só tem 80),
      // o motor distribui o saldo negativo igualmente para a fábrica saber que estourou.
      if (restante > 0) {
        int i = 0;
        while (restante > 0) {
          String cor = coresOrdenadas[i % coresOrdenadas.length];
          distribuicao[cor] = (distribuicao[cor] ?? 0) + 1;
          restante--;
          i++;
        }
      }
    }
    // ==========================================
    // LÓGICA 2: VENDA PROGRAMADA (Divisão Igualitária)
    // ==========================================
    else {
      int basePorCor = quantidadeTotal ~/ coresAtivas.length;
      int sobra = quantidadeTotal % coresAtivas.length;

      for (int i = 0; i < coresAtivas.length; i++) {
        String cor = coresAtivas[i];
        // Distribui a base igual para todas, e as sobras vão uma a uma para as primeiras cores
        distribuicao[cor] = basePorCor + (i < sobra ? 1 : 0);
      }
    }

    return distribuicao;
  }
}
