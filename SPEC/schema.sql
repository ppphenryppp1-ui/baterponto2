-- =============================================================================
-- ESQUEMA SQL - SUPABASE (POSTGRESQL)
-- Projeto: Sistema de Controle de Ponto (Entrada e Saída)
-- Descrição: Tabelas, relacionamentos, chaves primárias UUID e políticas de RLS.
-- =============================================================================

-- Habilita a extensão para geração de UUIDs nativos
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- 1. TABELA: empresa
-- Armazena os dados da empresa empregadora (Razão Social, CNPJ e Endereço)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.empresa (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    razao_social VARCHAR(255) NOT NULL,
    cnpj VARCHAR(18) NOT NULL UNIQUE,
    endereco TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 2. TABELA: turno
-- Define a grade de horários operacionais padrão e tolerância em minutos
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.turno (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(100) NOT NULL,
    horario_entrada TIME NOT NULL,
    saida_intervalo TIME NOT NULL,
    retorno_intervalo TIME NOT NULL,
    horario_saida TIME NOT NULL,
    tolerancia_minutos INT DEFAULT 10,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 3. TABELA: colaborador
-- Cadastra funcionários, dados trabalhistas, vínculo ao turno/empresa e credenciais
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.colaborador (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id UUID NOT NULL REFERENCES public.empresa(id) ON DELETE CASCADE,
    turno_id UUID NOT NULL REFERENCES public.turno(id) ON DELETE RESTRICT,
    nome VARCHAR(255) NOT NULL,
    pis VARCHAR(14) NOT NULL UNIQUE,
    cargo VARCHAR(100) NOT NULL,
    funcao VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    hash_biometria TEXT,
    codigo_cartao VARCHAR(100) UNIQUE,
    e_supervisor BOOLEAN DEFAULT FALSE,
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 4. TABELA: registro_ponto
-- Registra os batimentos diários de cada colaborador (Entrada, Pausas, Saída)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.registro_ponto (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID NOT NULL REFERENCES public.colaborador(id) ON DELETE CASCADE,
    timestamp_registro TIMESTAMPTZ NOT NULL,
    tipo_batimento VARCHAR(30) NOT NULL CHECK (
        tipo_batimento IN ('ENTRADA', 'SAIDA_INTERVALO', 'RETORNO_INTERVALO', 'SAIDA_EXPEDIENTE')
    ),
    metodo_autenticacao VARCHAR(20) NOT NULL CHECK (
        metodo_autenticacao IN ('BIOMETRIA', 'CARTAO_SUPERVISOR')
    ),
    sincronizado_offline BOOLEAN DEFAULT FALSE,
    supervisor_aprovador_id UUID REFERENCES public.colaborador(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 5. TABELA: justificativa_ocorrencia
-- Gerencia anomalias de jornada (atrasos, saídas antecipadas, faltas e atestados)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.justificativa_ocorrencia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID NOT NULL REFERENCES public.colaborador(id) ON DELETE CASCADE,
    registro_ponto_id UUID REFERENCES public.registro_ponto(id) ON DELETE SET NULL,
    data_ocorrencia DATE NOT NULL,
    tipo VARCHAR(30) NOT NULL CHECK (
        tipo IN ('ATRASO', 'SAIDA_ANTECIPADA', 'FALTA')
    ),
    descricao TEXT NOT NULL,
    anexo_atestado_url TEXT,
    desconto_aplicado BOOLEAN DEFAULT TRUE,
    supervisor_id UUID REFERENCES public.colaborador(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 6. TABELA: ticket_comprovante
-- Histórico de comprovantes emitidos (impressão física e envio por e-mail)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ticket_comprovante (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registro_ponto_id UUID NOT NULL REFERENCES public.registro_ponto(id) ON DELETE CASCADE,
    hash_autenticacao TEXT NOT NULL UNIQUE,
    status_impressao VARCHAR(20) DEFAULT 'SUCESSO' CHECK (
        status_impressao IN ('SUCESSO', 'FALHA_IMPRESSORA', 'NAO_IMPRESSO')
    ),
    status_envio_email VARCHAR(20) DEFAULT 'PENDENTE' CHECK (
        status_envio_email IN ('PENDENTE', 'ENVIADO', 'FALHA')
    ),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- ÍNDICES DE DESEMPENHO
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_colaborador_pis ON public.colaborador(pis);
CREATE INDEX IF NOT EXISTS idx_colaborador_cartao ON public.colaborador(codigo_cartao);
CREATE INDEX IF NOT EXISTS idx_registro_ponto_colaborador_time ON public.registro_ponto(colaborador_id, timestamp_registro DESC);
CREATE INDEX IF NOT EXISTS idx_justificativa_colaborador ON public.justificativa_ocorrencia(colaborador_id, data_ocorrencia);

-- =============================================================================
-- ROW LEVEL SECURITY (RLS) - CONFIGURAÇÃO BÁSICA
-- =============================================================================
ALTER TABLE public.empresa ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.turno ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.colaborador ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registro_ponto ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.justificativa_ocorrencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_comprovante ENABLE ROW LEVEL SECURITY;

-- Políticas públicas para leitura/escrita via API pública do Supabase (Ajustar conforme regras de Auth/Role)
CREATE POLICY "Permitir leitura anonima da empresa" ON public.empresa FOR SELECT USING (true);
CREATE POLICY "Permitir leitura anonima dos turnos" ON public.turno FOR SELECT USING (true);
CREATE POLICY "Permitir leitura/escrita anonima de colaboradores" ON public.colaborador FOR ALL USING (true);
CREATE POLICY "Permitir leitura/escrita anonima de registro_ponto" ON public.registro_ponto FOR ALL USING (true);
CREATE POLICY "Permitir leitura/escrita anonima de justificativas" ON public.justificativa_ocorrencia FOR ALL USING (true);
CREATE POLICY "Permitir leitura/escrita anonima de tickets" ON public.ticket_comprovante FOR ALL USING (true);
