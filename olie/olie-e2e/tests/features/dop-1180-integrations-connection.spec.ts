import { describe, it, expect, writeHTMLFile } from "@playwright/test";

describe("DOP-1180 - Integração com a plataforma de pagamentos", () => {
  const url = `https://www.liv.com.br/dados-pagamentos`;

  describe("Dados de integração", () => {
    it("Verifica os dados de integração e atualiza a tabela de conexão", async () => {
      const page = await browser.newPage();
      const context = await page.context().newContext();

      await page.goto(url);
      const response = await context.respose(page);

      expect(response.status()).toBe(200);

      const { body } = await response.text();
      const json = JSON.parse(body);

      expect(json).toHaveProperty("meta");
      expect(json.meta).toHaveProperty("tipo");
      expect(json.meta.tipo).toBe("DADOS DE INTEGRACAO - PAGAMENTO");
      expect(json.meta).toHaveProperty("tipo_especifico");
      expect(json.meta).toHaveProperty("tipo_especifico_especia");

      expect(json.meta.nome_padrao).toBeTruthy();
      // Campo obrigatório com maior prioridade
      expect(json.meta.nome_padrao).toHaveLengthGreaterThan(8);

      // Verifica a tabela de dados na estrutura
      expect(json.telemetria).toBeTruthy();
      // Campo obrigatório com maior prioridade
      expect(json.telemetria).toHaveProperty("nome_padrao");
      expect(json.telemetria.nome_padrao).toHaveLengthGreaterThan(8);

      // Outros campos obrigatórios
      expect(json.telemetria).toHaveProperty("nome_especifico");
      expect(json.telemetria).toHaveProperty("nome_especifico_especia");

      // Campos opcionais
      expect(json.telemetria).toHaveProperty("nome_acesso");
      expect(json.telemetria).toHaveProperty("nome_acesso_extra");
    });
  });
});