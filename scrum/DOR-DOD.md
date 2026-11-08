# Definition of Ready e Definition of Done

Acordo do time sobre quando uma história está pronta para começar e quando está concluída. Fica visível no quadro e é aplicado no planning e na review.

## Definition of Ready (pronta para entrar na sprint)

Uma história só entra na sprint quando:

- [ ] tem critérios de aceite claros;
- [ ] as dependências (outros serviços, decisões do professor) são conhecidas;
- [ ] tem estimativa de esforço atribuída;
- [ ] cabe em uma sprint (se não couber, foi dividida);
- [ ] tem um responsável nomeado.

## Definition of Done (considerada concluída)

Uma história só é concluída quando:

- [ ] o código foi revisado (Pull Request com ao menos uma aprovação);
- [ ] os testes automatizados passam no pipeline de CI;
- [ ] a documentação afetada foi atualizada;
- [ ] o funcionamento é demonstrável na Sprint Review;
- [ ] a etapa na planilha e no quadro foi atualizada para `concluído`.

## Por que isso importa para o desafio

O enunciado não aceita projeto sem execução automatizada de testes no pipeline (RP10) e pede desenvolvimento incremental com entregas funcionais a cada sprint (RP06).
