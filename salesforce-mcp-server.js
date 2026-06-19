import jsforce from "jsforce";
import { execSync } from "child_process";
import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const SF_ORG_ALIAS = process.env.SF_ORG_ALIAS || "myorg";

function getSFCredentials() {
  try {
    const raw = execSync(
      `sf org display --target-org ${SF_ORG_ALIAS} --json`,
      { encoding: "utf8" }
    );
    const parsed = JSON.parse(raw);
    const { instanceUrl, accessToken } = parsed.result;
    if (!instanceUrl || !accessToken) throw new Error("Missing instanceUrl or accessToken");
    return { instanceUrl, accessToken };
  } catch (err) {
    console.error(`Failed to get Salesforce credentials for org '${SF_ORG_ALIAS}':`, err.message);
    process.exit(1);
  }
}

const { instanceUrl, accessToken } = getSFCredentials();

const conn = new jsforce.Connection({ instanceUrl, accessToken });

const server = new McpServer({ name: "salesforce", version: "1.0.0" });

server.tool(
  "soql_query",
  "Execute a SOQL query against the Salesforce org",
  { query: z.string().min(1).describe("SOQL query string, e.g. SELECT Id, Name FROM Account LIMIT 10") },
  async ({ query }) => {
    try {
      const result = await conn.query(query);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    } catch (err) {
      return {
        content: [{ type: "text", text: `soql_query failed\n${err.message}` }],
        isError: true
      };
    }
  }
);

server.tool(
  "describe_object",
  "Get field and relationship metadata for a Salesforce sObject",
  { objectName: z.string().min(1).describe("API name, e.g. Account, Contact, TransactionJournal__c") },
  async ({ objectName }) => {
    try {
      const meta = await conn.describe(objectName);
      const fields = meta.fields.map((f) => ({
        name: f.name,
        label: f.label,
        type: f.type,
        length: f.length,
        nillable: f.nillable,
        updateable: f.updateable
      }));
      return { content: [{ type: "text", text: JSON.stringify({ name: meta.name, label: meta.label, fields }, null, 2) }] };
    } catch (err) {
      return {
        content: [{ type: "text", text: `describe_object failed\n${err.message}` }],
        isError: true
      };
    }
  }
);

server.tool(
  "get_record",
  "Retrieve a single Salesforce record by Id",
  {
    objectName: z.string().min(1).describe("sObject API name, e.g. Account"),
    recordId: z.string().min(1).describe("18-char Salesforce record Id"),
    fields: z.string().optional().describe("Comma-separated field API names; omit to get all fields")
  },
  async ({ objectName, recordId, fields }) => {
    try {
      const fieldList = fields ? fields.split(",").map((f) => f.trim()) : undefined;
      const result = fieldList
        ? await conn.sobject(objectName).retrieve(recordId, fieldList)
        : await conn.sobject(objectName).retrieve(recordId);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    } catch (err) {
      return {
        content: [{ type: "text", text: `get_record failed\n${err.message}` }],
        isError: true
      };
    }
  }
);

server.tool(
  "create_record",
  "Create a new Salesforce record",
  {
    objectName: z.string().min(1).describe("sObject API name, e.g. Account"),
    fieldsJson: z.string().min(1).describe("JSON object of field API names and values, e.g. {\"Name\":\"Acme\",\"Industry\":\"Tech\"}")
  },
  async ({ objectName, fieldsJson }) => {
    try {
      const fields = JSON.parse(fieldsJson);
      const result = await conn.sobject(objectName).create(fields);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    } catch (err) {
      return {
        content: [{ type: "text", text: `create_record failed\n${err.message}` }],
        isError: true
      };
    }
  }
);

server.tool(
  "update_record",
  "Update fields on an existing Salesforce record",
  {
    objectName: z.string().min(1).describe("sObject API name, e.g. Account"),
    recordId: z.string().min(1).describe("18-char Salesforce record Id"),
    fieldsJson: z.string().min(1).describe("JSON object of field API names and new values, e.g. {\"Name\":\"NewName\"}")
  },
  async ({ objectName, recordId, fieldsJson }) => {
    try {
      const fields = JSON.parse(fieldsJson);
      const result = await conn.sobject(objectName).update({ Id: recordId, ...fields });
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    } catch (err) {
      return {
        content: [{ type: "text", text: `update_record failed\n${err.message}` }],
        isError: true
      };
    }
  }
);

server.tool(
  "execute_apex",
  "Execute anonymous Apex code in the org",
  { apexCode: z.string().min(1).describe("Apex code to execute anonymously") },
  async ({ apexCode }) => {
    try {
      const result = await conn.tooling.executeAnonymous(apexCode);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    } catch (err) {
      return {
        content: [{ type: "text", text: `execute_apex failed\n${err.message}` }],
        isError: true
      };
    }
  }
);

server.tool(
  "list_objects",
  "List all sObject API names available in the org",
  { filter: z.string().optional().describe("Optional substring filter on object name or label") },
  async ({ filter }) => {
    try {
      const global = await conn.describeGlobal();
      let objects = global.sobjects.map((s) => ({ name: s.name, label: s.label }));
      if (filter) {
        const f = filter.toLowerCase();
        objects = objects.filter((o) => o.name.toLowerCase().includes(f) || o.label.toLowerCase().includes(f));
      }
      return { content: [{ type: "text", text: JSON.stringify(objects, null, 2) }] };
    } catch (err) {
      return {
        content: [{ type: "text", text: `list_objects failed\n${err.message}` }],
        isError: true
      };
    }
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
