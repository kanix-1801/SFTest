/**
* @description       : This Class is used to invoke Cardcom Transaction API.
* @author            :
* @group             :
* @last modified on  : 07-10-2025
* @last modified by  :
**/
public class CardcomTransactionInvoker {
  /**
   * description      : This is org setting Name.
   * @param           : CARD_COM_TRANSACTION_API_URL - CardcomTransactionApiUrl
   */
  public static string CARD_COM_TRANSACTION_API_URL = 'CardcomTransactionApiUrl';

  /**
   * description      : This Method is used to send transaction request to Cardcom
   * @param           : requests - TransactionRequest
   * @return          : none
   */
  @InvocableMethod(
    label='Send Transaction to Cardcom'
    description='Invokes a transaction request to Cardcom from Flow'
  )
  public static List<TransactionResponse> invokeTransaction(
    List<TransactionRequest> requests
  ) {
    List<TransactionResponse> responses = new List<TransactionResponse>();

    for (TransactionRequest input : requests) {
      TransactionResponse output = new TransactionResponse();
      Http http = new Http();
      HttpRequest req = new HttpRequest();
      HttpResponse res;
      req.setEndpoint(
        'callout:Cardcom_PROD' +
        OrgSettingHelpers.getString(
          CARD_COM_TRANSACTION_API_URL,
          '/api/v11/Transactions/Transaction'
        )
      ); // Named Credential

      req.setMethod('POST');
      req.setHeader('Content-Type', 'application/json');
      String jsonBody = getRequestBody(input);
      System.debug('Cardcom Transaction JSON Request: ' + jsonBody);
      req.setTimeout(120000);

      req.setBody(jsonBody);
      Integer calloutAttempts = 0;
      try {
        do {
          Integer calloutAttempted = Limits.getCallouts();
          System.debug('====calloutAttempted===' + calloutAttempted);
          if (calloutAttempted >= 100)
            break;
          res = http.send(req);
          output.statusCode = res.getStatusCode();
          output.responseBody = res.getBody();
          System.debug('====response===' + res);
        } while (res.getStatusCode() != 200 && calloutAttempts++ < 10);

        if (res.getStatusCode() == 200) {
          output.success = true;
          output.message = 'Transaction processed successfully.';
        } else {
          output.success = false;
          output.message = 'Failed with HTTP status ' + res.getStatusCode();
        }
      } catch (Exception e) {
        output.success = false;
        output.message = 'Exception: ' + e.getMessage();
        output.statusCode = 500;
        output.responseBody = null;
      }
      responses.add(output);
    }
    return responses;
  }

  /**
   * description      : This Method is used to Create Request body for Transaction
   * @param           : input - TransactionRequest
   * @return          : requestBody - String
   */
  public static string getRequestBody(TransactionRequest input) {
    Map<String, Object> requestBody = new Map<String, Object>{
      'TerminalNumber' => input.terminalNumber,
      'ApiName' => input.apiName,
      'Amount' => input.amount,
      'ISOCoinId' => input.isoCoinId,
      'Advanced' => new Map<String, Object>{
        'Advanced' => input.advanced != null ? input.advanced : '',
        'IsRefund' => input.isRefund,
        'AccountIdToGetCardNumber' => input.accountIdToGetCardNumber
      },
      'Document' => new Map<String, Object>{
        'DocumentTypeToCreate' => input.documentTypeToCreate,
        'Name' => input.documentName,
        'IsSendByEmail' => input.isSendByEmail,
        'Email' => input.email,
        'Phone' => input.phone,
        'Products' => new List<Object>{
          new Map<String, Object>{
            'Description' => input.productDescription,
            'UnitCost' => input.productUnitCost
          }
        },
        'AdvancedDefinition' => new Map<String, Object>{
          'IsLoadInfoFromAccountID' => input.isLoadInfoFromAccountId,
          'AccountID' => input.accountId
        }
      }
    };
    return JSON.serialize(requestBody);
  }

  /**
   * description     : Inner class to build JSON request body
   * @param           : None
   * @return          : None
   */
  public class TransactionRequest {
    @InvocableVariable
    public String terminalNumber;

    @InvocableVariable
    public String apiName;

    @InvocableVariable
    public Decimal amount;

    @InvocableVariable
    public String isoCoinId;

    @InvocableVariable
    public String advanced;

    @InvocableVariable
    public Boolean isRefund;

    @InvocableVariable
    public String accountIdToGetCardNumber;

    @InvocableVariable
    public String documentTypeToCreate;

    @InvocableVariable
    public String documentName;

    @InvocableVariable
    public String isSendByEmail;

    @InvocableVariable
    public String productDescription;

    @InvocableVariable
    public Decimal productUnitCost;

    @InvocableVariable
    public String email;

    @InvocableVariable
    public String phone;

    @InvocableVariable
    public String isLoadInfoFromAccountId;

    @InvocableVariable
    public String accountId;
  }

  // Output class for response
  public class TransactionResponse {
    @InvocableVariable
    public Boolean success;

    @InvocableVariable
    public Integer statusCode;

    @InvocableVariable
    public String message;

    @InvocableVariable
    public String responseBody;
  }
}