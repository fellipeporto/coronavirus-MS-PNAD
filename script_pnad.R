setwd('D:/R/estudoR/covid19_R/homework7_pnad')

install.packages('readxl')
# carregando pacotes 

library(tidyverse)
library(srvyr)
library(readr)
library(readxl)

# carregando os microdados da PNAD COVID 

pnad_covid <- read_csv("PNAD_COVID_112020.csv",
                       col_types = cols(.default = "d"))


estados <- read_excel(
  "Dicionario_PNAD_COVID_112020.xls", 
  sheet = "dicion�rio pnad covid",
  skip = 4, n_max = 27
) %>%
  select(UF = ...5, estado = ...6)

pnad <- pnad_covid %>%
  left_join(estados, by = "UF")

head(estados)
View(pnad_covid)

# definindo pesos das variaveis

pnad_pesos <- pnad_covid %>%
  as_survey_design(ids = UPA,
                   strata = Estrato,
                   weights = V1032,
                   nest = TRUE) %>%
  filter(UF == "35")

# criando colunas com vari�veis de interesse. SUPER INTERESSANTE

pnad_pesos <- pnad_pesos %>% mutate(one = 1,
                                    Sexo = ifelse(A003 == 1, "Homem", "Mulher"), ##SE A VARI�VEL FOR IGUAL A 1,  HOMEM, CASO CONTR�RIO MULHER. 
                                    Idade = case_when(
                                      A002 %in% 15:24 ~ "15-24",
                                      A002 %in% 25:34 ~ "25-34", 
                                      A002 %in% 35:49 ~ "35-49", 
                                      A002 %in% 50:64 ~ "50-64", 
                                      A002 > 64 ~ "65+"),
                                    Cor = case_when(
                                      A004 == 1 ~ "Branca", 
                                      A004 == 2 ~ "Preta", 
                                      A004 == 4 ~ "Parda"),
                                    Escolaridade = factor(case_when(  ##usando factor conseguimos ordenar
                                      A005 %in% 1:2 ~ "Sem Instru��o ou Fundamental Incompleto", 
                                      A005 %in% 3:4 ~ "Fundamental completo ou M�dio Incompleto", 
                                      A005 %in% 5:6 ~ "M�dio completo ou Superior Incompleto", 
                                      A005 == 7 ~ "Superior completo", 
                                      A005 == 8 ~ "P�s-gradua��o"), 
                                      levels = c( "Sem Instru��o ou Fundamental Incompleto",
                                                  "Fundamental completo ou M�dio Incompleto", 
                                                  "M�dio completo ou Superior Incompleto",
                                                  "Superior completo",
                                                  "P�s-gradua��o")), 
                                    Tipo_emprego = factor(case_when(
                                      C007 == 1 ~ "Trabalhador dom�stico (empregado dom�stico, cuidados, bab�)",
                                      C007 == 2 ~ "Militar",
                                      C007 == 3 ~ "Policial ou Bombeiro",
                                      C007 == 4 ~ "Setor privado",
                                      C007 == 5 ~ "Setor p�blico",
                                      C007 == 6 ~ "Empregador",
                                      C007 == 7 ~ "Aut�nomo (Conta pr�pria)"),
                                      levels = c( "Trabalhador dom�stico (empregado dom�stico, cuidados, bab�)",
                                                  "Militar", 
                                                  "Policial ou Bombeiro",
                                                  "Setor privado",
                                                  "Setor p�blico",
                                                  "Empregador",
                                                  "Aut�nomo (Conta pr�pria)")), 
                                    Faixa_salario = factor(case_when(
                                      C01012 <= 1044 ~ "Menos de um sal�rio m�nimo",
                                      C01012 %in% c(1045:2090) ~ "Entre 1 e 2",
                                      C01012 %in% c(2091:3135) ~ "Entre 2 e 3",
                                      C01012 %in% c(3136:4180) ~ "Entre 3 e 4",
                                      C01012 %in% c(4181:5225) ~ "Entre 4 e 5",
                                      C01012 >= 5226 ~ "Mais de 5"),
                                      levels = c("Menos de um sal�rio m�nimo",
                                                 "Entre 1 e 2",
                                                 "Entre 2 e 3",
                                                 "Entre 3 e 4",
                                                 "Entre 4 e 5",
                                                 "Mais de 5")),
                                    domicilio_situacao = factor(case_when(
                                      F001 == 1 ~ "Pr�prio - j� pago",
                                      F001 == 2 ~ "Pr�prio - ainda pagando" ,                                  
                                      F001 == 3 ~ "Alugado",
                                      F001 %in% 4:6 ~ "Cedido (Por empregador, Familiar ou outro)"),
                                      levels = c("Pr�prio - j� pago",
                                                 "Pr�prio - ainda pagando",
                                                 "Alugado", 
                                                 "Cedido (Por empregador, Familiar ou outro)")),
                                    home_office = ifelse(C013 == 1, "Home Office", "Presencial"),
                                    auxilio_emergencial = ifelse(D0051 == 1, "Aux�lio", "Sem aux�lio")
)


# separando um conjunto de dados para fazer o gr�fico desejado

home_sexo_cor <- pnad_pesos %>%
  group_by(Sexo, Cor) %>%
  summarise(
    home_office = survey_total(C013 == 1, na.rm = TRUE),  #na.rm = TRUE remove valores ausentes
    mao_de_obra = survey_total(C001 == 1, na.rm = TRUE)) %>%
  mutate(trab_home_office = (home_office/mao_de_obra)*100) %>%
  drop_na()

# Agora vamos fazer o gr�fico
home_sexo_cor_ssa <- ggplot(home_sexo_cor, aes(fill = Cor, y = trab_home_office, x = Sexo)) +
  geom_bar(position = "dodge", stat = "identity") +
  geom_text(aes(label=sprintf("%1.2f%%",trab_home_office)),size = 3, position =position_dodge(width=0.9),
            vjust=-0.5, color = 'black',fontface='bold') +
  theme_classic() +
  theme(axis.title.x = element_text(colour = "black"),
        axis.title.y = element_text(colour = "black"),
        axis.text.y = element_text(face="bold", color="#000000", 
                                   size=10),
        axis.line = element_line(colour = "black", 
                                 size = 1, linetype = "solid"),     # borda do gr�fico mais escura e grossa
        axis.text=element_text(size=6, face="bold"),
        axis.text.x = element_text(face="bold", color="#000000", size=10),
        plot.title = element_text(colour = "black", size = 17, hjust=0.5),
        legend.position = "bottom", legend.background = element_rect(fill="ghostwhite", size=0.7, linetype="blank")) +
  labs(x = "Sexo", fill = "Cor/Ra�a: ", caption = "Fonte: Microdados da Pnad Covid19 - IBGE. Novembro/ 2020.",
       title = "Pessoas em home office, por cor/ra�a e sexo - S�o Paulo/SP") +
  scale_fill_manual(values = c("#00b894","#ff7675","#0984e3","#6c5ce7")) +
  scale_y_discrete(limits=factor(0:100), breaks = c(0,10,20,30,40,50,60,70,80,90,100), name = "Percentual (%)")

home_sexo_cor_ssa

# fazendo o mesmo para n�vel de escolaridade

home_edu_cor <- pnad_pesos %>%
  group_by(Escolaridade, Cor) %>%
  summarise(
    home_office = survey_total(C013 == 1, na.rm = TRUE),
    mao_de_obra = survey_total(C001 == 1, na.rm = TRUE)
  ) %>%
  mutate(trab_home_office = (home_office/mao_de_obra)*100) %>%
  drop_na()
# gr�fico
home_edu_cor_ssa <- ggplot(home_edu_cor, aes(fill = Escolaridade, y = trab_home_office, x = Cor)) +
  geom_bar(position = "dodge", stat = "identity") +
  geom_text(aes(label=sprintf("%1.2f%%",trab_home_office)),size = 3, position =position_dodge(width=0.9),
            vjust=-0.5, color = 'black',fontface='bold') +
  theme_classic() +
  theme(axis.title.x = element_text(colour = "black"),
        axis.title.y = element_text(colour = "black"),
        axis.text.y = element_text(face="bold", color="#000000", 
                                   size=10),
        axis.line = element_line(colour = "black", 
                                 size = 1, linetype = "solid"),
        axis.text=element_text(size=6, face="bold"),
        axis.text.x = element_text(face="bold", color="#000000", size=10),
        plot.title = element_text(colour = "black", size = 17, hjust=0.5),
        legend.position = "bottom", legend.background = element_rect(fill="ghostwhite", size=0.7, linetype="blank")) +
  labs(x = "Cor/Ra�a", fill = "Escolaridade: ", caption = "Fonte: Microdados da Pnad Covid19 - IBGE. Novembro/ 2020.",
       title = "Pessoas em home office, por cor/ra�a e escolaridade - S�o Paulo/SP ") +
  scale_fill_manual(values = c("#00b894","#ff7675","#0984e3","#6c5ce7","#fdcb6e")) +
  scale_y_discrete(limits=factor(0:100), breaks = c(0,10,20,30,40,50,60,70,80,90,100), name = "Percentual (%)")


home_edu_cor_ssa


# o mesmo para faixa et�ria 

home_sexo_idade <- pnad_pesos %>%
  group_by(Sexo, Idade) %>%
  summarise(
    home_office = survey_total(C013 == 1, na.rm = TRUE),
    mao_de_obra = survey_total(C001 == 1, na.rm = TRUE)
  ) %>%
  mutate(trab_home_office = (home_office/mao_de_obra)*100) %>%
  drop_na()
# gr�fico
home_sexo_idade_ssa <- ggplot(home_sexo_idade, aes(fill = Idade, y = trab_home_office, x = Sexo)) +
  geom_bar(position = "dodge", stat = "identity") +
  geom_text(aes(label=sprintf("%1.2f%%",trab_home_office)),size = 3, position =position_dodge(width=0.9),
            vjust=-0.5, color = 'black',fontface='bold') +
  theme_classic() +
  theme(axis.title.x = element_text(colour = "black"),
        axis.title.y = element_text(colour = "black"),
        axis.text.y = element_text(face="bold", color="#000000", 
                                   size=10),
        axis.line = element_line(colour = "black", 
                                 size = 1, linetype = "solid"),
        axis.text=element_text(size=6, face="bold"),
        axis.text.x = element_text(face="bold", color="#000000", size=10),
        plot.title = element_text(colour = "black", size = 17, hjust=0.5),
        legend.position = "bottom", legend.background = element_rect(fill="ghostwhite", size=0.7, linetype="blank")) +
  labs(x = "Sexo", fill = "Faixa Et�ria: ", caption = "Fonte: Microdados da Pnad Covid19 - IBGE. Novembro 2020.",
       title = "Pessoas em home office, por sexo e faixa et�ria - S�o Paulo/SP") +
  scale_fill_manual(values = c("#00b894","#ff7675","#0984e3","#6c5ce7","#fdcb6e")) +
  scale_y_discrete(limits=factor(0:100), breaks = c(0,10,20,30,40,50,60,70,80,90,100), name = "Percentual (%)")


home_sexo_idade_ssa


