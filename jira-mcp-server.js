import axios from "axios";
import { z } from "zod";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const JIRA_BASE_URL = process.env.JIRA_BASE_URL;
const JIRA_EMAIL = process.env.JIRA_EMAIL;
const JIRA_API_TOKEN = process.env.JIRA_API_TOKEN;

if (!JIRA_BASE_URL || !JIRA_EMAIL || !JIRA_API_TOKEN) {
  console.error("Missing JIRA_BASE_URL, JIRA_EMAIL, or JIRA_API_TOKEN");
  process.exit(1);
}

const auth = Buffer.from(`${JIRA_EMAIL}:${JIRA_API_TOKEN}`).toString("base64");

const jira = axios.create({
  baseURL: `${JIRA_BASE_URL}/rest/api/3`,
  headers: {
    Authorization: `Basic ${auth}`,
    Accept: "application/json",
    "Content-Type": "application/json"
  },
  timeout: 30000
});

const server = new McpServer({
  name: "jira",
  version: "1.0.0"
});

server.tool(
  "get_issue",
  "Get a Jira issue by key, for example LYLT-15098",
  {
    key: z.string().min(1)
  },
  async ({ key }) => {
    try {
      const res = await jira.get(`/issue/${key}`);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(res.data, null, 2)
          }
        ]
      };
    } catch (error) {
      const message =
        error.response?.data
          ? JSON.stringify(error.response.data, null, 2)
          : error.message;

      return {
        content: [
          {
            type: "text",
            text: `Jira get_issue failed for ${key}\n${message}`
          }
        ],
        isError: true
      };
    }
  }
);

server.tool(
  "search_issues",
  "Search Jira issues using JQL",
  {
    jql: z.string().min(1)
  },
  async ({ jql }) => {
    try {
      const res = await jira.get("/search/jql", {
        params: { jql, maxResults: 100, fields: "summary,story_points,customfield_10016,customfield_10028,status,assignee" }
      });

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(res.data, null, 2)
          }
        ]
      };
    } catch (error) {
      const message =
        error.response?.data
          ? JSON.stringify(error.response.data, null, 2)
          : error.message;

      return {
        content: [
          {
            type: "text",
            text: `Jira search_issues failed\n${message}`
          }
        ],
        isError: true
      };
    }
  }
);

server.tool(
  "create_issue",
  "Create a Jira task issue",
  {
    projectKey: z.string().min(1),
    summary: z.string().min(1),
    description: z.string().min(1)
  },
  async ({ projectKey, summary, description }) => {
    try {
      const res = await jira.post("/issue", {
        fields: {
          project: { key: projectKey },
          summary,
          description,
          issuetype: { name: "Task" }
        }
      });

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(res.data, null, 2)
          }
        ]
      };
    } catch (error) {
      const message =
        error.response?.data
          ? JSON.stringify(error.response.data, null, 2)
          : error.message;

      return {
        content: [
          {
            type: "text",
            text: `Jira create_issue failed\n${message}`
          }
        ],
        isError: true
      };
    }
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);