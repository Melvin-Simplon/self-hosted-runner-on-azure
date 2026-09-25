# Consignes du projet

## Énoncé

> Provisionner une VM Azure avec Terraform, la configurer en runner self-hosted GitHub Actions (et optionnellement GitLab CI) avec Ansible, puis basculer une pipeline existante dessus pour mesurer le gain réel par rapport à un runner hébergé.
>
> L'ensemble du cycle (provisioning, configuration, exécution) doit être piloté depuis GitHub Actions/GitLab CI : aucune commande manuelle depuis le poste du candidat en dehors de la mise au point initiale.

## Objectifs

1. **Provisionner** une VM Linux sur Azure avec **Terraform**.
2. **Configurer** cette VM en runner **self-hosted GitHub Actions** avec **Ansible**.
3. **En option** : l'enregistrer aussi comme runner **GitLab CI**.
4. **Basculer** une pipeline existante sur ce runner.
5. **Mesurer** le gain réel face à un runner hébergé (`ubuntu-latest` côté GitHub, runners SaaS côté GitLab).

## Contrainte principale : tout passe par la CI

Le provisioning, la configuration et l'exécution sont **déclenchés par des pipelines**, jamais depuis le poste local.

Seule exception autorisée : la **mise au point initiale**. Par exemple :

- créer le stockage du state Terraform distant ;
- créer l'identité Azure utilisée par la CI (OIDC de préférence) ;
- déclarer les secrets du dépôt.

Tout ce qui est fait à la main doit être **documenté** pour rester reproductible.

## Découpage proposé

Ce découpage est une proposition d'organisation, il ne fait pas partie de l'énoncé.

1. **Bootstrap** (`terraform/bootstrap/`) : backend distant du state et identité CI. Seule étape manuelle.
2. **Infrastructure** (`terraform/modules/`, `terraform/environments/dev/`) : réseau, NSG, VM runner. Plan en PR, apply sur `main` via un workflow.
3. **Configuration** (`ansible/`) : rôle `common` (durcissement, paquets), rôle `github_runner`, rôle optionnel `gitlab_runner`. Lancé par un workflow après l'apply.
4. **Pipeline témoin** (`app/`) : projet dont la pipeline tourne d'abord sur runner hébergé, puis sur le runner self-hosted.
5. **Benchmark** (`benchmark/`, `docs/benchmark/`) : même pipeline, plusieurs exécutions sur chaque runner, comparaison chiffrée.
6. **Destruction** : un workflow dédié pour détruire l'infrastructure et maîtriser les coûts Azure.

## Points à mesurer

- **Durée totale** de la pipeline.
- **Durée par étape** (checkout, installation des dépendances, build, tests).
- **Effet du cache** : premier run à froid, puis runs suivants.
- **Temps d'attente** avant prise en charge du job.
- **Coût** : prix de la VM Azure comparé aux minutes facturées du runner hébergé.

Les runs doivent être **assez nombreux** pour que la comparaison soit crédible (moyenne et médiane, pas un seul essai).

## Points de vigilance

- **Aucun secret** dans le dépôt : secrets GitHub/GitLab, Ansible Vault ou Azure Key Vault.
- **Dépôt public** : un runner self-hosted sur un dépôt public peut exécuter le code d'une PR externe. Restreindre les workflows qui ciblent ce runner.
- **Accès SSH** à la VM limité (NSG restreint, clé uniquement).
- **Idempotence** : relancer Terraform et Ansible ne doit rien casser.

## Livrables attendus

- Code Terraform et Ansible versionné.
- Workflows CI couvrant provisioning, configuration, exécution et destruction.
- Rapport de benchmark avec les chiffres bruts et l'analyse.
- Documentation de la mise au point initiale.
