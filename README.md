

# Projeto WordPress com Docker na AWS | Compass UOL

Este repositório contém a implementação de uma arquitetura completa para o deploy de uma aplicação **WordPress** utilizando **Docker** sobre a infraestrutura da **Amazon Web Services (AWS)**. O projeto foi desenvolvido como parte do programa de bolsas **DevSecOps** promovido pela **Compass UOL**, com foco na criação de soluções escaláveis, resilientes e seguras.

A infraestrutura foi pensada para fornecer **alta disponibilidade**, **persistência de dados**, **balanceamento de carga** e **escalabilidade automática**, aproveitando o ecossistema da AWS. A aplicação WordPress é containerizada com Docker, e seus dados são persistidos de forma confiável através de integrações com **Amazon RDS** (banco de dados) e **Amazon EFS** (sistema de arquivos compartilhado).

---

## Objetivos do Projeto

* Implantar uma aplicação WordPress containerizada com Docker.
* Utilizar os principais serviços da AWS para criar uma infraestrutura escalável.
* Garantir a persistência de dados mesmo em ambientes efêmeros (Auto Scaling).
* Automatizar a criação e o gerenciamento de recursos com boas práticas de segurança.
* Monitorar a infraestrutura e torná-la capaz de reagir a variações de carga de trabalho.

---

## Tecnologias e Serviços Utilizados

Este projeto utiliza um conjunto diversificado de tecnologias e serviços, fundamentais para uma arquitetura moderna em nuvem:

* **Amazon VPC**: para segmentação de rede e isolamento seguro dos recursos.
* **Amazon EC2 (Linux 2023)**: instâncias virtuais para execução dos contêineres.
* **Docker e Docker Compose**: para empacotar e orquestrar a aplicação WordPress e seus serviços dependentes.
* **Amazon RDS (MySQL)**: banco de dados relacional gerenciado, garantindo segurança, escalabilidade e backups automáticos.
* **Amazon EFS**: sistema de arquivos compartilhado entre instâncias, essencial para o funcionamento de múltiplos contêineres WordPress simultâneos.
* **Classic Load Balancer (CLB)**: para distribuir as requisições de entrada entre as instâncias EC2 de forma eficiente.
* **Auto Scaling Group (ASG)**: para aumentar ou reduzir dinamicamente a quantidade de instâncias com base na demanda.
* **Amazon CloudWatch**: para monitoramento, coleta de métricas e ações automatizadas.

---

## Etapas de Construção da Infraestrutura

### 1. Criação da VPC (Virtual Private Cloud)

A VPC é o primeiro passo para estruturar a rede. Criamos:

* **2 sub-redes públicas** (para o Load Balancer).
* **2 sub-redes privadas** (para as instâncias EC2).
* Um **NAT Gateway** para permitir que as instâncias privadas tenham acesso à internet para atualizações e instalação de pacotes.
* Seleção de múltiplas **Availability Zones**, assegurando tolerância a falhas regionais.

### 2. Configuração dos Grupos de Segurança

Foram criados quatro Security Groups, cada um com regras bem definidas:

* **sgelb**: permite tráfego HTTP, HTTPS e SSH.
* **sgec2**: permite apenas tráfego vindo do Load Balancer, do EFS e do RDS.
* **sgrds**: acessível apenas pelas instâncias EC2 que hospedam o WordPress.
* **sgefs**: permite comunicação bidirecional com as instâncias EC2.

Essas regras garantem **segmentação de segurança** entre os serviços e evitam exposição desnecessária.


# Security Groups Configuration

| Security Group | Type         | Direction | Protocol | Ports    | Source/Destination  |
|----------------|--------------|-----------|----------|----------|---------------------|
| sgelb          | Load Balancer| Inbound   | HTTP     | 80       | 0.0.0.0/0           |
|                |              | Inbound   | HTTPS    | 443      | 0.0.0.0/0           |
|                |              | Inbound   | SSH      | 22       | My IP               |
|                |              | Outbound  | All      | All      | 0.0.0.0/0           |
| sgec2          | EC2 Instance | Inbound   | HTTP     | 80       | sgelb               |
|                |              | Inbound   | HTTPS    | 443      | sgelb               |
|                |              | Inbound   | NFS      | 2049     | sgefs               |
|                |              | Inbound   | MySQL    | 3306     | sgrds               |
|                |              | Inbound   | SSH      | 22       | My IP               |
|                |              | Outbound  | All      | All      | 0.0.0.0/0           |
| sgefs          | EFS          | Inbound   | NFS      | 2049     | sgec2               |
|                |              | Outbound  | NFS      | 2049     | sgec2               |
| sgrds          | RDS          | Inbound   | MySQL    | 3306     | sgec2               |
|                |              | Outbound  | MySQL    | 3306     | sgec2               |


### 3. Banco de Dados (RDS)

O RDS é responsável por armazenar as informações persistentes da aplicação WordPress. A instância é configurada com:

- Vá para **Aurora and RDS** > **Databases** e clique em **Create database**.
- Selecione **MySQL** e configure o banco de dados com as seguintes opções:
  - **Engine Version**: última versão disponível.
  - **Templates**: selecione **Free tier**.
  - Personalize o nome do banco de dados e o nome de usuário, definindo uma senha. 
  - Escolha a instância **db.t3.micro**. 
  - **Connectivity**: selecione **Don’t connect to an EC2 compute resource**, associe ao grupo de segurança `sgrds` e à VPC ***wordpress-vpc***.
  - **Additional configuration**: defina um nome para a base de dados.

- Finalize clicando em **Create database**.


### 4. Sistema de Arquivos (EFS)

O EFS garante que múltiplas instâncias EC2 possam compartilhar arquivos — um requisito para o WordPress quando rodando em alta disponibilidade.

- Acesse a seção **EFS** e clique em **Create file system**.
- Selecione a VPC criada e clique em **Customize**
- Escolha as duas sub-redes privadas e o grupo de segurança do **sgefs**.
- Finalize clicando em **Create**.


### 5. Launch Template (Template de Lançamento)

Configuramos um modelo de instância que define:

- Vá para a seção **EC2** e acesse **Launch Templates** > **Create launch template**.
- Personalize com o nome e a descrição.
- Selecione **Amazon Linux 2023 AMI** e **t2.micro**.
- Vincule o grupo de segurança Web e adicione as tags necessárias.
- Use o script de [**User Data**](user-data.sh) disponível neste repositório, fazendo as seguintes alterações:
  - Substitua `EFS_DNS` pelo ID do sistema de arquivos EFS.
  - Substitua `DB_HOST` pelo endpoint do banco de dados.
  - Substitua `DB_NAME`, `DB_HOST` e `DB_PASSWORD` pelas credenciais do banco de dados.

- Finalize clicando em **Create launch template**.


### 6. Load Balancer

O Load Balancer atua como a porta de entrada da aplicação, recebendo requisições HTTP e redirecionando para as instâncias saudáveis.

- No menu lateral, acesse **Load Balancers** > **Create load balancer** > **Classic Load Balancer**. 
- Configure as opções:
  - **Scheme**: Internet-facing.
  - **VPC**: escolha a VPC criada.
  - **Availability Zones**: selecione as zonas de disponibilidade e as sub-redes públicas.
  - **Security groups**: associe ao grupo de segurança criado para o Load Balancer.
  - **Listeners and routing**: defina para HTTP na porta 80.
  - **Health Checks**: configure os parâmetros da seguinte maneira:
    - **Ping protocol**: escolha HTTP.
    - **Ping port**: defina 80.
    - **Ping path**: insira `/wp-admin/install.php`.

- Finalize clicando em **Create load balancer**.


### 7. Auto Scaling Group (ASG)

Criamos um Auto Scaling Group baseado no Launch Template. Configuração:

- Acesse **Auto Scaling Groups** > **Create Auto Scaling group**.
- Dê um nome e selecione o **Launch Template** criado anteriormente.
- Configure a VPC e as sub-redes privadas.
- Associe o Load Balancer criado no passo anterior.
- Marque a opção **Turn on Elastic Load Balancing health checks**.
- Configure a capacidade da seguinte maneira:
  - **Desired capacity**: 2.
  - **Min desired capacity**: 2.
  - **Max desired capacity**: 4.

- Selecione **No scaling policies**. 
- Marque a opção **Enable group metrics collection within CloudWatch**.
- Adicone as tags que desejar.
- Finalize clicando em **Create Auto Scaling group**. 

### 8. Acesso à Aplicação WordPress

Com a infraestrutura em funcionamento:

* Copie o **DNS público** do Load Balancer.
* Acesse via navegador.
* Complete o processo de instalação e configuração inicial do WordPress.

---

## Resultados e Benefícios

Com esta estrutura, obtemos:

* **Alta disponibilidade**: instâncias distribuídas em diferentes zonas de disponibilidade.
* **Escalabilidade automática**: via Auto Scaling, com base em métricas reais de uso.
* **Persistência de dados**: mesmo que as instâncias sejam terminadas, o banco (RDS) e o sistema de arquivos (EFS) mantêm os dados.
* **Isolamento e segurança**: através de VPC, sub-redes e grupos de segurança.
* **Facilidade de manutenção**: o uso de Launch Templates e scripts automatiza o provisionamento.

---
