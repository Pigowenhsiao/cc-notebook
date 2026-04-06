# Notion Ai DataBase View 全量遞迴讀取報告（2026-04-06）

## 範圍與方法
- 目標資料庫：`https://www.notion.so/039bbec4bfc044e8854a6239c80d8182`
- 目標 data source：`collection://6c262f43-ffdb-4b3b-b5a5-38c02ac8a2e1`
- 列舉批次（搜尋關鍵字）：`AI`、`Claude`、`Codex`、`Notion`、`Prompt`
- 每批上限：`page_size=25`
- 遞迴規則：對已發現頁面執行 `notion-fetch`，並追蹤子頁面/子資料源再 fetch

## 已讀頁面清單（128）
- `18242529badd8099b405cf24f3eb7602`
- `16342529badd80beacfbd2bb0e51a598`
- `33342529badd80cbad6cdc4fe765d685`
- `32c42529badd806c881ac8a3e20b982d`
- `33742529badd80e8b3cdf416711e2df3`
- `1ff42529badd8070be39c974b28d2690`
- `1d742529badd80cf84b4c310e23f68df`
- `2af42529badd8066bb3ad78b3ff97dcd`
- `25142529badd8009aa54d8d16b427a62`
- `33942529badd80f7abaef98b44c16192`
- `33742529badd80638e33d8c43c9aabc1`
- `31942529badd8016b62bd22961d7d6bd`
- `26442529badd80b1b38ceed7af4056e0`
- `1b742529badd8062a60cd296d674cd11`
- `28442529badd8071aaa1f4d719f6b9b0`
- `30c1d002d35b4e37a55946f4f0dfea88`
- `d47c33e6b9d44cd08d23f6780f6b95f2`
- `27b42529badd80349279d56318088f90`
- `ab372841dbaf46b09717225c8af09208`
- `4dd7194cbd5b4e68a7d83bbed329a092`
- `30242529badd8036b33fea5846a5f883`
- `2cd42529badd807b9980ee4d93ddf8d1`
- `32c42529badd804a99abd32a4655681a`
- `31042529badd80058311ff0a2f508360`
- `16342529badd8052b0cacf97a8d28dab`
- `19442529badd80fbac30d5a78277d04c`
- `11642529badd8032bf6ad542f1f879b4`
- `5560f4bdbfee4a07aa132879c834865d`
- `48696297cb184eb9a07fa654bd14944d`
- `0b6e2400fdd84c9b91877054eaa4cc71`
- `2f150968a044404fbd731edff80fe040`
- `7e377c11d533480cb713b3960c249bd6`
- `38846dab68694df393edbad6638dbc78`
- `bc10a74b28654b9f9a0e86b234e625bc`
- `d63bfecd48ca46669a0ff65a6e0695ea`
- `60316c4707c84bb5bb843539da87560e`
- `168459671dee4d00ab0712ad746727b7`
- `57f2c0b92ab94875b3d3fdec85ea1995`
- `516b47c81a0940b7bc5ffc32547cdd2b`
- `7b713651de2545d295ac18564ae1d146`
- `19142529badd80ebab9fe63afd4cee98`
- `9773ada2ef5d43b0a215e631879be4a6`
- `79ffaae581d8446ea98275ce5df4f8f0`
- `2e142529badd802bb59bf01bc7a44755`
- `17242529badd80feb4dee0ee86c0a895`
- `33342529badd80bcb81af412b8fbb147`

本輪已補讀原 B 類 82 筆頁面，完整 ID 清單：`.tmp_unread_b_ids.txt`（已全部轉為已讀）。

## 未讀清單與原因

### A. 權限 / 不存在
- `24f05c28a18880d2b67bdfdc26acce32`：`object_not_found`（可能無權限或頁面不存在）

### B. 其他
- 已清空（本輪 82 筆皆可成功 `fetch`）。

## 備註（全量保證限制）
- 此 Connector 的 `notion-search` 無空查詢、單批最多 25 筆且無游標，故無法用單一路徑證明「完全無漏頁」。
- 已採用多關鍵字分批 + 去重 + 遞迴 fetch；本輪已完成原 B 類補讀。
